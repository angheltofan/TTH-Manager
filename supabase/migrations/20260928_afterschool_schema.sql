-- ─────────────────────────────────────────────────────────────────────
-- 20260928_afterschool_schema — Afterschool module, Phase 1
-- ─────────────────────────────────────────────────────────────────────
--
-- Creates five new tables for the Afterschool module and their RLS.
-- Completely isolated from the workshop-cycle system:
--   • no FK to `workshop_series`, `scheduled_workshops`,
--     `workshop_enrollments`, `attendance`, `payment_cycles`
--   • no trigger touches any workshop table
--   • no change to `recalculate_child_series_payment_cycles` or the
--     paid_advance flow
--
-- Tables:
--   1. afterschool_programs
--   2. afterschool_enrollments
--   3. afterschool_sessions
--   4. afterschool_attendance
--   5. afterschool_monthly_payments
--
-- All authorization uses the existing server-side helpers:
--   is_admin(), is_staff(), is_parent(), is_parent_for_child(uuid).
-- No dependency on is_trainer_for_child() (which resolves the
-- relationship only through workshops).
--
-- Additive + safe to re-run in a fresh database. `create table if not
-- exists` semantics not used because policies + indexes would collide
-- on partial replays; drop the tables manually if you need to reseed
-- during Phase 1 review.
-- ─────────────────────────────────────────────────────────────────────

-- ── Isolated updated_at trigger helper ───────────────────────────────
-- Self-contained so this module does not depend on any global helper.
create or replace function public.afterschool_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.afterschool_set_updated_at() is
  'Local trigger helper for Afterschool module tables. Kept separate '
  'from any global set_updated_at() so the module has no hidden '
  'coupling.';

-- ═════════════════════════════════════════════════════════════════════
-- 1. afterschool_programs
-- ═════════════════════════════════════════════════════════════════════

create table public.afterschool_programs (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  description       text,
  days_of_week      smallint[] not null,
  start_time        time not null,
  end_time          time not null,
  monthly_fee       numeric(10, 2) not null,
  currency          text not null default 'RON',
  max_capacity      integer,
  active_from       date not null,
  active_to         date,
  is_active         boolean not null default true,
  archived_at       timestamptz,
  archived_by       uuid references public.profiles(id) on delete set null,
  archived_reason   text,
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint chk_afs_prog_name_nonempty
    check (length(trim(name)) > 0),
  constraint chk_afs_prog_days_of_week
    check (
      cardinality(days_of_week) between 1 and 7
      and days_of_week <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
    ),
  constraint chk_afs_prog_time_order
    check (end_time > start_time),
  constraint chk_afs_prog_fee_positive
    check (monthly_fee > 0),
  constraint chk_afs_prog_currency_nonempty
    check (length(trim(currency)) > 0),
  constraint chk_afs_prog_max_capacity_positive
    check (max_capacity is null or max_capacity > 0),
  constraint chk_afs_prog_dates
    check (active_to is null or active_to >= active_from),
  constraint chk_afs_prog_archive_consistency
    check (
      (archived_at is null)
      or (archived_at is not null and is_active = false)
    )
);

comment on table public.afterschool_programs is
  'Configuration of one Afterschool program (days, hours, monthly fee, '
  'active period). Multiple programs may coexist. Archiving flips '
  'is_active + sets archived_at; sessions previously generated are '
  'preserved for history.';

comment on column public.afterschool_programs.days_of_week is
  'ISO weekday numbers (1=Monday .. 7=Sunday). e.g. {1,2,3,4,5} for L-V.';

comment on column public.afterschool_programs.max_capacity is
  'Optional hard cap on active enrolled children. NULL = no cap. NOT '
  'enforced by trigger in Phase 1 — repository/UI computes '
  '"active enrolled / max_capacity" and warns when reached. A future '
  'trigger may harden this once the admin-override policy is decided.';

create index idx_afs_programs_active
  on public.afterschool_programs (is_active)
  where is_active = true;

create trigger tg_afs_programs_updated_at
  before update on public.afterschool_programs
  for each row execute function public.afterschool_set_updated_at();

-- ═════════════════════════════════════════════════════════════════════
-- 2. afterschool_enrollments
-- ═════════════════════════════════════════════════════════════════════

create table public.afterschool_enrollments (
  id                     uuid primary key default gen_random_uuid(),
  child_id               uuid not null references public.children(id) on delete restrict,
  program_id             uuid not null references public.afterschool_programs(id) on delete restrict,
  enrolled_from          date not null,
  enrolled_until         date,
  custom_monthly_fee     numeric(10, 2),
  attendance_days        smallint[],
  expected_arrival_time  time,
  is_active              boolean not null default true,
  notes                  text,
  enrolled_by            uuid references public.profiles(id) on delete set null,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),

  constraint chk_afs_enr_dates
    check (enrolled_until is null or enrolled_until >= enrolled_from),
  constraint chk_afs_enr_custom_fee_positive
    check (custom_monthly_fee is null or custom_monthly_fee > 0),
  constraint chk_afs_enr_attendance_days_shape
    check (
      attendance_days is null
      or (
        cardinality(attendance_days) between 1 and 7
        and attendance_days <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
      )
    )
);

comment on table public.afterschool_enrollments is
  'Historical record of a child''s Afterschool enrollment. Multiple '
  'rows per (child, program) allowed to preserve past periods. Active '
  'enrollment = is_active AND enrolled_from <= today AND '
  '(enrolled_until IS NULL OR enrolled_until >= today).';

comment on column public.afterschool_enrollments.custom_monthly_fee is
  'Overrides the program''s monthly_fee for this child. NULL means '
  '"inherit from program". Used for scholarships or negotiated rates.';

comment on column public.afterschool_enrollments.attendance_days is
  'Per-child schedule inside the program''s week. ISO weekday numbers '
  '(1=Monday..7=Sunday). NULL = child follows every program day. When '
  'set, MUST be a subset of the program''s days_of_week — enforced by '
  'the trg_afs_enr_attendance_days_subset trigger. Eligibility for a '
  'session date = enrollment covers date AND '
  '(attendance_days IS NULL OR isodow(date) = ANY(attendance_days)).';

comment on column public.afterschool_enrollments.expected_arrival_time is
  'Informational only. When a child normally arrives later than the '
  'program''s start_time (school schedule dependency). Does NOT change '
  'attendance semantics — status stays present/absent/unmarked.';

-- One active enrollment per (child, program) — historical/closed rows
-- are allowed to coexist with a new active one.
create unique index uq_afs_enr_active
  on public.afterschool_enrollments (child_id, program_id)
  where is_active = true and enrolled_until is null;

create index idx_afs_enr_child_program
  on public.afterschool_enrollments (child_id, program_id);

create index idx_afs_enr_program_active
  on public.afterschool_enrollments (program_id)
  where is_active = true and enrolled_until is null;

-- ── Subset-of-program-days trigger ──────────────────────────────────
-- Enforces attendance_days ⊆ program.days_of_week whenever the row is
-- inserted or the (attendance_days, program_id) pair changes. Kept as a
-- trigger — not a CHECK — because CHECK cannot reference another table.
-- A trigger applies uniformly to admin RPCs, PostgREST writes, and any
-- future admin SQL, so no code path can bypass it.
--
-- Deliberately NOT paired with a trigger on afterschool_programs that
-- would block narrowing `days_of_week` when active enrollments still
-- reference a day being removed — that would over-restrict admin
-- operations. UI in Phase 2 will warn/refuse; DB tolerates the drift.

create or replace function public.afterschool_validate_enrollment_days()
returns trigger
language plpgsql
as $$
declare
  v_program_days smallint[];
begin
  if new.attendance_days is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.attendance_days is not distinct from old.attendance_days
     and new.program_id is not distinct from old.program_id then
    return new;
  end if;

  select days_of_week
    into v_program_days
    from public.afterschool_programs
    where id = new.program_id;

  if v_program_days is null then
    raise exception 'program_not_found: %', new.program_id;
  end if;

  if not (new.attendance_days <@ v_program_days) then
    raise exception
      'attendance_days_not_subset_of_program_days: enrollment=% program=%',
      new.id, new.program_id;
  end if;

  return new;
end;
$$;

comment on function public.afterschool_validate_enrollment_days() is
  'BEFORE INSERT/UPDATE trigger for afterschool_enrollments. Ensures '
  'attendance_days is a subset of the referenced program''s days_of_week.';

create trigger tg_afs_enr_attendance_days_subset
  before insert or update on public.afterschool_enrollments
  for each row execute function public.afterschool_validate_enrollment_days();

create trigger tg_afs_enrollments_updated_at
  before update on public.afterschool_enrollments
  for each row execute function public.afterschool_set_updated_at();

-- ═════════════════════════════════════════════════════════════════════
-- 3. afterschool_sessions
-- ═════════════════════════════════════════════════════════════════════

create table public.afterschool_sessions (
  id              uuid primary key default gen_random_uuid(),
  program_id      uuid not null references public.afterschool_programs(id) on delete restrict,
  session_date    date not null,
  start_time      time not null,
  end_time        time not null,
  variant         text not null default 'regular',
  is_closed       boolean not null default false,
  closed_reason   text,
  closed_by       uuid references public.profiles(id) on delete set null,
  closed_at       timestamptz,
  created_at      timestamptz not null default now(),

  constraint chk_afs_sess_variant
    check (variant in ('regular', 'special')),
  constraint chk_afs_sess_time_order
    check (end_time > start_time),
  constraint chk_afs_sess_closed_consistency
    check (
      (is_closed = false and closed_at is null and closed_by is null)
      or (is_closed = true and closed_at is not null)
    )
);

comment on table public.afterschool_sessions is
  'One row per program-day. Generated deterministically by '
  'generate_afterschool_sessions_window(). is_closed = day declared '
  'CLOSED (holiday / center closed / cancelled). variant = ''regular'' '
  'today; extensible to ''special'' for future non-standard days '
  'without a schema change.';

comment on column public.afterschool_sessions.variant is
  'Session type. Starts with regular/special so the calendar can be '
  'extended to non-standard days (special programs, moved hours) '
  'without another migration.';

create unique index uq_afs_sess_program_date
  on public.afterschool_sessions (program_id, session_date);

create index idx_afs_sess_date
  on public.afterschool_sessions (session_date);

-- ═════════════════════════════════════════════════════════════════════
-- 4. afterschool_attendance
-- ═════════════════════════════════════════════════════════════════════

create table public.afterschool_attendance (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid not null references public.afterschool_sessions(id) on delete restrict,
  child_id      uuid not null references public.children(id) on delete restrict,
  status        text not null,
  observation   text,
  marked_at     timestamptz not null default now(),
  marked_by     uuid references public.profiles(id) on delete set null,
  updated_at    timestamptz not null default now(),

  constraint chk_afs_att_status
    check (status in ('present', 'absent'))
);

comment on table public.afterschool_attendance is
  'Presence per (session, child). UNMARKED is represented by the '
  'ABSENCE of a row (no INSERT). status is strictly present/absent — '
  'no motivated. session→attendance FK is RESTRICT so a session can '
  'never be deleted while attendance survives.';

create unique index uq_afs_att_session_child
  on public.afterschool_attendance (session_id, child_id);

create index idx_afs_att_child
  on public.afterschool_attendance (child_id, session_id);

create index idx_afs_att_session
  on public.afterschool_attendance (session_id);

create trigger tg_afs_attendance_updated_at
  before update on public.afterschool_attendance
  for each row execute function public.afterschool_set_updated_at();

-- ═════════════════════════════════════════════════════════════════════
-- 5. afterschool_monthly_payments
-- ═════════════════════════════════════════════════════════════════════

create table public.afterschool_monthly_payments (
  id                uuid primary key default gen_random_uuid(),
  child_id          uuid not null references public.children(id) on delete restrict,
  program_id        uuid not null references public.afterschool_programs(id) on delete restrict,
  year              smallint not null,
  month             smallint not null,
  amount            numeric(10, 2) not null,
  currency          text not null default 'RON',
  status            text not null default 'due',
  paid_at           timestamptz,
  payment_method    text,
  confirmed_by      uuid references public.profiles(id) on delete set null,
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint chk_afs_pay_year   check (year between 2000 and 2100),
  constraint chk_afs_pay_month  check (month between 1 and 12),
  constraint chk_afs_pay_amount check (amount >= 0),
  constraint chk_afs_pay_status
    check (status in ('due', 'paid', 'cancelled')),
  constraint chk_afs_pay_method
    check (payment_method is null or payment_method in ('pos', 'op')),
  constraint chk_afs_pay_paid_consistency
    check (
      (status = 'paid'
        and payment_method is not null
        and paid_at is not null
        and confirmed_by is not null)
      or (status <> 'paid')
    )
);

comment on table public.afterschool_monthly_payments is
  'Monthly billing state per (child, program, year, month). amount is '
  'a SNAPSHOT at the moment the row is created; later program fee '
  'changes never rewrite history. status transitions: due → paid, '
  'due → cancelled. Rows are never deleted (audit trail).';

comment on column public.afterschool_monthly_payments.amount is
  'Snapshot of the BASE TUITION owed for this month, taken at '
  'materialization. Program monthly_fee changes DO NOT retroactively '
  'rewrite this. If the enrollment had a custom_monthly_fee at snapshot '
  'time, that value was captured here. '
  'NOTE: today the whole monthly bill IS this amount, but future '
  'billable items (optional lunch, materials, extras) will be modelled '
  'via their own tables/columns rather than by inflating this snapshot. '
  'Consumers must not assume `amount` is the child''s complete bill '
  'forever — always sum through the dedicated aggregation layer when '
  'those items ship.';

create unique index uq_afs_pay_child_program_ym
  on public.afterschool_monthly_payments (child_id, program_id, year, month);

create index idx_afs_pay_program_ym_status
  on public.afterschool_monthly_payments (program_id, year, month, status);

create index idx_afs_pay_child_program
  on public.afterschool_monthly_payments (child_id, program_id);

create trigger tg_afs_payments_updated_at
  before update on public.afterschool_monthly_payments
  for each row execute function public.afterschool_set_updated_at();

-- ═════════════════════════════════════════════════════════════════════
-- RLS
-- ═════════════════════════════════════════════════════════════════════
--
-- Authorization matrix (relies on public.is_admin(), public.is_staff(),
-- public.is_parent(), public.is_parent_for_child(uuid)):
--
--                     SELECT           INSERT   UPDATE   DELETE
-- programs            staff|parent     admin    admin    admin
-- enrollments         staff|parent(c)  admin    admin    admin
-- sessions            staff|parent(c)  admin    admin    (none)
-- attendance          staff|parent(c)  staff    staff    admin
-- monthly_payments    staff|parent(c)  staff    staff    (none)
--
-- parent(c) = is_parent_for_child(child_id) evaluated on the row.
-- (none)    = no policy = no access under RLS.
--
-- Note: attendance and monthly_payments allow trainers to write, per
-- the business decision "admin and trainer may mark attendance and
-- confirm payments" from Phase 0 Q3. Enrollment management stays
-- admin-only, matching the pattern used by workshop_enrollments.

-- ── programs ────────────────────────────────────────────────────────
alter table public.afterschool_programs enable row level security;

create policy afs_programs_select_staff_parent
  on public.afterschool_programs
  for select
  using (public.is_staff() or public.is_parent());

create policy afs_programs_insert_admin
  on public.afterschool_programs
  for insert
  with check (public.is_admin());

create policy afs_programs_update_admin
  on public.afterschool_programs
  for update
  using (public.is_admin())
  with check (public.is_admin());

create policy afs_programs_delete_admin
  on public.afterschool_programs
  for delete
  using (public.is_admin());

-- ── enrollments ─────────────────────────────────────────────────────
alter table public.afterschool_enrollments enable row level security;

create policy afs_enrollments_select_staff
  on public.afterschool_enrollments
  for select
  using (public.is_staff());

create policy afs_enrollments_select_parent
  on public.afterschool_enrollments
  for select
  using (public.is_parent_for_child(child_id));

create policy afs_enrollments_insert_admin
  on public.afterschool_enrollments
  for insert
  with check (public.is_admin());

create policy afs_enrollments_update_admin
  on public.afterschool_enrollments
  for update
  using (public.is_admin())
  with check (public.is_admin());

create policy afs_enrollments_delete_admin
  on public.afterschool_enrollments
  for delete
  using (public.is_admin());

-- ── sessions ────────────────────────────────────────────────────────
alter table public.afterschool_sessions enable row level security;

create policy afs_sessions_select_staff
  on public.afterschool_sessions
  for select
  using (public.is_staff());

-- Parent may see the session iff they have a child whose active or
-- past enrollment references the same program. Session dates outside
-- the enrollment window are still visible so the parent's calendar
-- renders context — the enrollment RLS separately restricts which
-- children they see enrolled.
create policy afs_sessions_select_parent
  on public.afterschool_sessions
  for select
  using (
    exists (
      select 1
      from public.afterschool_enrollments e
      where e.program_id = public.afterschool_sessions.program_id
        and public.is_parent_for_child(e.child_id)
    )
  );

create policy afs_sessions_insert_admin
  on public.afterschool_sessions
  for insert
  with check (public.is_admin());

create policy afs_sessions_update_admin
  on public.afterschool_sessions
  for update
  using (public.is_admin())
  with check (public.is_admin());

-- No delete policy → sessions are never deleted via client RLS. If a
-- session must go away, admin runs the delete via server RPC (not
-- planned in Phase 1).

-- ── attendance ──────────────────────────────────────────────────────
alter table public.afterschool_attendance enable row level security;

create policy afs_attendance_select_staff
  on public.afterschool_attendance
  for select
  using (public.is_staff());

create policy afs_attendance_select_parent
  on public.afterschool_attendance
  for select
  using (public.is_parent_for_child(child_id));

create policy afs_attendance_insert_staff
  on public.afterschool_attendance
  for insert
  with check (public.is_staff());

create policy afs_attendance_update_staff
  on public.afterschool_attendance
  for update
  using (public.is_staff())
  with check (public.is_staff());

create policy afs_attendance_delete_admin
  on public.afterschool_attendance
  for delete
  using (public.is_admin());

-- ── monthly_payments ────────────────────────────────────────────────
alter table public.afterschool_monthly_payments enable row level security;

create policy afs_payments_select_staff
  on public.afterschool_monthly_payments
  for select
  using (public.is_staff());

create policy afs_payments_select_parent
  on public.afterschool_monthly_payments
  for select
  using (public.is_parent_for_child(child_id));

create policy afs_payments_insert_staff
  on public.afterschool_monthly_payments
  for insert
  with check (public.is_staff());

create policy afs_payments_update_staff
  on public.afterschool_monthly_payments
  for update
  using (public.is_staff())
  with check (public.is_staff());

-- No delete policy → payment rows are permanent audit trail.
