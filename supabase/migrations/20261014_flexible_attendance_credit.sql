-- ═══════════════════════════════════════════════════════════════════════════
-- 20261014 — Flexible attendance credit ("Prezență în altă grupă")
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Business rule: a child enrolled in workshop series A (regular group) may
-- physically attend session S of workshop series B (another group of the
-- SAME educational workshop — matching `workshop_type`). The physical
-- attendance is recorded against session S's roster (visible to the
-- trainer running the Monday session), but the billing credit MUST flow
-- to the child's existing four-session cycle on series A.
--
-- Design — add one optional override column to `attendance`:
--
--   attendance.credited_series_id uuid references workshop_series(id)
--
--   NULL              — regular attendance, credits its own physical series
--                       (existing behaviour, bit-for-bit preserved).
--   <uuid of series A>— visitor attendance; the destination roster still
--                       shows this child, but the recalc routes the credit
--                       to series A instead of the physical series.
--
-- Invariants enforced by trigger `validate_attendance_credit_trg`:
--   I1  credited_series_id must reference a workshop_series row.
--   I2  the credited series and the physical series must share the SAME
--       `workshop_type` (string equality on the existing canonical label).
--   I3  the child must hold an ACTIVE workshop_enrollments row on the
--       credited series (so the credit lands on a real cycle for a real
--       enrollment that belongs to the same child).
--   I4  the attendance must NOT also be the destination of a non-cancelled
--       makeup_sessions row (double-credit guard between the two flows).
--   I5  the credited series cannot equal the physical series (that would
--       be an ambiguous no-op; omit the column instead).
--
-- Recalc: `recalculate_child_series_payment_cycles(child, series)` is
-- rewritten so that the chronological presence stream for a given series
-- is the UNION of:
--   (a) native rows: physical series = this series AND credited_series_id
--       IS NULL AND not a destination of a makeup_sessions row;
--   (b) visitor-credited rows: credited_series_id = this series.
-- This mirrors the pattern used by 20261006 for makeup destinations.
--
-- Trigger fan-out: the attendance recalc trigger now also recalculates
-- the credited series on INSERT/UPDATE/DELETE, including both OLD and NEW
-- credited series on an UPDATE that moves the override.
--
-- Compatibility: this migration is designed on the Stage 3.1 baseline
-- (migrations through 20261006 applied). It REFUSES to apply if the
-- Stage 3.2 recalc (20261007) is present, to avoid overwriting the
-- UNION-based recalc with a stale body. In that case a dedicated
-- Stage 3.2-aware variant must be authored instead.
--
-- Rollback is non-destructive: dropping the column + reverting the two
-- functions to their 20261006 bodies fully restores previous behaviour.
-- See the trailing "ROLLBACK" comment block for the exact SQL.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ── 0. Baseline guard ─────────────────────────────────────────────────────
-- Refuse to run on a schema where 20261007 (Stage 3.2.1 advance recovery
-- recalc V2) has already been applied. The function body in V2 differs
-- materially; a safe credit extension requires a separate migration.
do $baseline$
begin
  if exists (
    select 1
      from information_schema.tables
      where table_schema = 'supabase_migrations'
        and table_name = 'schema_migrations'
  ) then
    if exists (
      select 1
        from supabase_migrations.schema_migrations
        where version = '20261007'
    ) then
      raise exception
        'Refusing to apply 20261014: 20261007 (Stage 3.2 recalc V2) is '
        'already applied. Author a Stage 3.2-aware variant before running '
        'this migration on that baseline.';
    end if;
  end if;
end
$baseline$;

-- ── 1. Column + supporting index ──────────────────────────────────────────
alter table public.attendance
  add column if not exists credited_series_id uuid
    references public.workshop_series(id) on delete set null;

comment on column public.attendance.credited_series_id is
  'Optional override. When NULL the attendance credits its own physical '
  'series (standard behaviour). When set, the billing credit flows to '
  'the referenced workshop_series instead, provided the child has an '
  'active enrollment on it and both series share the same workshop_type. '
  'Enforced by validate_attendance_credit_trg.';

create index if not exists attendance_credited_series_idx
  on public.attendance (credited_series_id)
  where credited_series_id is not null;

-- ── 2. Validation function + trigger ─────────────────────────────────────
-- Marked VOLATILE (default) and SECURITY DEFINER so it can read
-- workshop_series, scheduled_workshops, workshop_enrollments and
-- makeup_sessions regardless of the caller's RLS. Explicit search_path
-- avoids search_path hijacking.

create or replace function public.validate_attendance_credit()
returns trigger
language plpgsql
security definer
set search_path = public
as $validate$
declare
  v_physical_series_id uuid;
  v_physical_wtype text;
  v_credited_wtype text;
  v_enrollment_active boolean;
  v_makeup_dest boolean;
begin
  -- Fast path: NULL override preserves prior behaviour.
  if new.credited_series_id is null then
    return new;
  end if;

  -- Resolve the physical series of the attendance's scheduled_workshop.
  select coalesce(sw.series_id, sw.recurring_series_id), sw.workshop_type
    into v_physical_series_id, v_physical_wtype
    from public.scheduled_workshops sw
    where sw.id = new.scheduled_workshop_id;

  if v_physical_series_id is null then
    raise exception
      'validate_attendance_credit: scheduled_workshop % has no resolvable series',
      new.scheduled_workshop_id
    using errcode = '23514';
  end if;

  -- I5: credited != physical
  if new.credited_series_id = v_physical_series_id then
    raise exception
      'validate_attendance_credit: credited_series_id equals the physical '
      'series of the scheduled_workshop; omit the override instead'
    using errcode = '23514';
  end if;

  -- I1 + I2: credited series exists and shares the same workshop_type.
  select workshop_type into v_credited_wtype
    from public.workshop_series
    where id = new.credited_series_id;

  if v_credited_wtype is null then
    raise exception
      'validate_attendance_credit: credited_series_id % does not exist',
      new.credited_series_id
    using errcode = '23503';
  end if;

  if v_physical_wtype is null
     or v_credited_wtype is null
     or v_physical_wtype <> v_credited_wtype then
    raise exception
      'validate_attendance_credit: cross-workshop attendance not allowed '
      '(physical workshop_type=% vs credited workshop_type=%)',
      v_physical_wtype, v_credited_wtype
    using errcode = '23514';
  end if;

  -- I3: child must have an ACTIVE enrollment on the credited series.
  select exists (
    select 1
      from public.workshop_enrollments we
     where we.child_id = new.child_id
       and we.series_id = new.credited_series_id
       and we.is_active = true
  ) into v_enrollment_active;

  if not v_enrollment_active then
    raise exception
      'validate_attendance_credit: child % has no active enrollment on '
      'credited_series %',
      new.child_id, new.credited_series_id
    using errcode = '23514';
  end if;

  -- I4: double-credit guard — the attendance cannot also be the
  -- destination of a non-cancelled makeup_sessions row. Only enforced
  -- when the makeup_sessions table exists (post 20261006).
  if to_regclass('public.makeup_sessions') is not null then
    select exists (
      select 1
        from public.makeup_sessions ms
       where ms.makeup_attendance_id = new.id
         and ms.status <> 'cancelled'
    ) into v_makeup_dest;

    if v_makeup_dest then
      raise exception
        'validate_attendance_credit: attendance % is already credited via '
        'makeup_sessions; cannot additionally set credited_series_id',
        new.id
      using errcode = '23514';
    end if;
  end if;

  return new;
end;
$validate$;

comment on function public.validate_attendance_credit() is
  'Enforces I1..I5 for attendance.credited_series_id. Rejects '
  'cross-workshop attendance, missing enrollments and double-credit '
  'with makeup_sessions.';

revoke all on function public.validate_attendance_credit() from public;

-- Attach the trigger. BEFORE INSERT OR UPDATE OF credited_series_id so
-- the usual markAttendance upsert that does NOT touch credited_series_id
-- bypasses validation at zero cost.
drop trigger if exists validate_attendance_credit_trg on public.attendance;
create trigger validate_attendance_credit_trg
  before insert or update of credited_series_id, scheduled_workshop_id, child_id
  on public.attendance
  for each row
  execute function public.validate_attendance_credit();

-- ── 3. Rewrite recalculate_child_series_payment_cycles (credit-aware) ────
-- Semantically identical to the 20261006 body except the chronological
-- presence SELECT and the "detach" UPDATE both widen their predicate to
-- cover the credited-series path.

create or replace function public.recalculate_child_series_payment_cycles(
  p_child_id uuid,
  p_series_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $recalc$
declare
  v_payment_type text;
  v_total_presents int;
  v_max_existing_rank int;
  v_cycle record;
  v_new_cycle_id uuid;
  v_advance record;
  v_chunk_start_date date;
  v_chunk_end_date date;
  v_chunk_wtype text;
  v_chunk_closing_ws uuid;
  v_updates int := 0;
  v_created int := 0;
  v_deleted int := 0;
  v_orphaned_paid int := 0;
  v_notifications int := 0;
  v_expected int;
begin
  if p_child_id is null or p_series_id is null then
    return jsonb_build_object('skipped', 'null_params');
  end if;

  perform pg_advisory_xact_lock(hashtext(
    'child_series_cycles:' || p_child_id::text || ':' || p_series_id::text));

  select payment_type into v_payment_type
    from public.children where id = p_child_id;
  if v_payment_type is null or v_payment_type = 'free' then
    return jsonb_build_object('skipped',
      case when v_payment_type is null then 'child_not_found'
           else 'free_child' end);
  end if;

  create temporary table if not exists tmp_series_presents (
    attendance_id uuid,
    scheduled_workshop_id uuid,
    workshop_date date,
    start_time time,
    workshop_type text,
    chrono_rank int
  ) on commit drop;
  truncate tmp_series_presents;

  insert into tmp_series_presents (
    attendance_id, scheduled_workshop_id, workshop_date, start_time,
    workshop_type, chrono_rank
  )
  select a.id, a.scheduled_workshop_id, sw.workshop_date,
         sw.start_time, sw.workshop_type,
         row_number() over (
           order by sw.workshop_date asc,
                    sw.start_time asc nulls first,
                    a.id asc
         )
  from public.attendance a
  join public.scheduled_workshops sw on sw.id = a.scheduled_workshop_id
  where a.child_id = p_child_id
    and a.status = 'present'
    and a.is_archived = false
    and (
      -- Native stream: physical series = this series AND not overridden
      -- by a credit route AND not a destination-side makeup row.
      (
        coalesce(sw.series_id, sw.recurring_series_id) = p_series_id
        and a.credited_series_id is null
        and (
          to_regclass('public.makeup_sessions') is null
          or not exists (
            select 1
              from public.makeup_sessions ms
             where ms.makeup_attendance_id = a.id
               and ms.status <> 'cancelled'
          )
        )
      )
      or
      -- Visitor-credited stream: the override points to this series.
      -- Guarded by validate_attendance_credit_trg so a.child_id is
      -- guaranteed to be enrolled in p_series_id.
      (
        a.credited_series_id = p_series_id
      )
    );

  select count(*) into v_total_presents from tmp_series_presents;
  v_expected := v_total_presents / 4;

  -- Detach previous cycle links for the rows that now belong to this
  -- series' credit stream. Mirrors the SELECT above exactly.
  update public.attendance a
    set payment_cycle_id = null
    from public.scheduled_workshops sw
    where sw.id = a.scheduled_workshop_id
      and a.child_id = p_child_id
      and a.payment_cycle_id is not null
      and (
        (
          coalesce(sw.series_id, sw.recurring_series_id) = p_series_id
          and a.credited_series_id is null
        )
        or a.credited_series_id = p_series_id
      );

  create temporary table if not exists tmp_series_cycles (
    cycle_id uuid,
    status text,
    created_at timestamptz,
    rank int
  ) on commit drop;
  truncate tmp_series_cycles;

  insert into tmp_series_cycles (cycle_id, status, created_at, rank)
  select id, status, created_at,
         row_number() over (order by created_at asc, id asc)
  from public.payment_cycles
  where child_id = p_child_id
    and series_id = p_series_id
    and status <> 'paid_advance';

  v_max_existing_rank := coalesce(
    (select max(rank) from tmp_series_cycles), 0);

  for i in 1..v_expected loop
    select
      min(workshop_date),
      max(workshop_date),
      (array_agg(workshop_type order by chrono_rank))[1],
      (array_agg(scheduled_workshop_id order by chrono_rank desc))[1]
    into v_chunk_start_date, v_chunk_end_date, v_chunk_wtype,
         v_chunk_closing_ws
    from tmp_series_presents
    where chrono_rank between (i - 1) * 4 + 1 and i * 4;

    if i <= v_max_existing_rank then
      select cycle_id into v_new_cycle_id
        from tmp_series_cycles where rank = i;

      update public.attendance set payment_cycle_id = v_new_cycle_id
        where id in (
          select attendance_id from tmp_series_presents
          where chrono_rank between (i - 1) * 4 + 1 and i * 4
        );

      update public.payment_cycles
        set period_start = v_chunk_start_date,
            period_end = v_chunk_end_date,
            sessions_count = 4
        where id = v_new_cycle_id;

      v_updates := v_updates + 1;
    else
      select id, payment_method, paid_at, confirmed_by
        into v_advance
        from public.payment_cycles
        where child_id = p_child_id
          and series_id = p_series_id
          and status = 'paid_advance'
        order by paid_at asc nulls last, created_at asc
        limit 1 for update;

      if v_advance.id is not null then
        insert into public.payment_cycles (
          child_id, series_id, workshop_type, sessions_count, status,
          period_start, period_end,
          payment_method, paid_at, confirmed_by, notes
        ) values (
          p_child_id, p_series_id, v_chunk_wtype, 4, 'paid',
          v_chunk_start_date, v_chunk_end_date,
          v_advance.payment_method, v_advance.paid_at,
          v_advance.confirmed_by,
          'Ciclu generat automat după 4 prezențe. Achitat în avans.'
        ) returning id into v_new_cycle_id;

        delete from public.payment_cycles where id = v_advance.id;
      else
        insert into public.payment_cycles (
          child_id, series_id, workshop_type, sessions_count, status,
          period_start, period_end, notes
        ) values (
          p_child_id, p_series_id, v_chunk_wtype, 4, 'due',
          v_chunk_start_date, v_chunk_end_date,
          'Ciclu generat automat după 4 prezențe.'
        ) returning id into v_new_cycle_id;

        insert into public.notifications (
          title, body, type, related_child_id, related_workshop_id
        ) values (
          'Plată necesară',
          'Copilul a acumulat 4 prezențe. A fost generat un ciclu de plată.',
          'payment',
          p_child_id,
          v_chunk_closing_ws
        );
        v_notifications := v_notifications + 1;
      end if;

      update public.attendance set payment_cycle_id = v_new_cycle_id
        where id in (
          select attendance_id from tmp_series_presents
          where chrono_rank between (i - 1) * 4 + 1 and i * 4
        );

      v_created := v_created + 1;
    end if;
  end loop;

  for v_cycle in
    select cycle_id, status from tmp_series_cycles
    where rank > v_expected order by rank
  loop
    if v_cycle.status in ('due', 'overdue', 'cancelled') then
      delete from public.payment_cycles where id = v_cycle.cycle_id;
      v_deleted := v_deleted + 1;
    else
      update public.payment_cycles
        set sessions_count = 0,
            notes = coalesce(notes, '') ||
              E'\n⚠ Ciclu orfan după recalculare cronologică — atendențele suportive au fost reasignate cronologic către alte cicluri sau au dispărut. Preservat pentru păstrarea istoricului financiar.'
        where id = v_cycle.cycle_id;
      v_orphaned_paid := v_orphaned_paid + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'child_id', p_child_id,
    'series_id', p_series_id,
    'total_presents', v_total_presents,
    'expected_cycles', v_expected,
    'existing_cycles_before', v_max_existing_rank,
    'cycles_reassigned', v_updates,
    'cycles_created', v_created,
    'cycles_deleted', v_deleted,
    'paid_cycles_orphaned', v_orphaned_paid,
    'notifications_created', v_notifications
  );
end;
$recalc$;

comment on function public.recalculate_child_series_payment_cycles(uuid, uuid) is
  'Deterministic per (child, series) chronological recalc. Includes the '
  'native stream (physical attendance in this series, no override, no '
  'makeup destination) and the visitor-credited stream (attendance in '
  'any session whose credited_series_id = this series). Idempotent.';

revoke all on function public.recalculate_child_series_payment_cycles(uuid, uuid)
  from public;
grant execute on function public.recalculate_child_series_payment_cycles(uuid, uuid)
  to authenticated, service_role;

-- ── 4. Rewrite the attendance recalc trigger (credit-aware fan-out) ──────
-- Fan-out semantics:
--   INSERT  — recalc physical series + credited series (if set).
--   DELETE  — recalc old physical series + old credited series (if set).
--   UPDATE  — recalc the union of {old physical, new physical, old
--             credited, new credited}, de-duplicated.
--
-- Self-recursion guard widened to include credited_series_id so a pure
-- credit-only UPDATE still triggers a recalc.

create or replace function public.tg_recalculate_cycles_on_attendance()
returns trigger
language plpgsql
as $trg$
declare
  v_child_id uuid;
  v_ws_id uuid;
  v_old_ws_id uuid;
  v_series_id uuid;
  v_old_series_id uuid;
  v_credited_new uuid;
  v_credited_old uuid;
  v_affected uuid[] := array[]::uuid[];
  v_dedup uuid[];
  v_s uuid;
begin
  -- Self-recursion guard — if NOTHING of substance changed, bail.
  if tg_op = 'UPDATE'
     and old.status is not distinct from new.status
     and old.is_archived is not distinct from new.is_archived
     and old.child_id is not distinct from new.child_id
     and old.scheduled_workshop_id is not distinct from
         new.scheduled_workshop_id
     and old.credited_series_id is not distinct from
         new.credited_series_id then
    return null;
  end if;

  v_child_id := case
    when tg_op = 'DELETE' then old.child_id
    else new.child_id
  end;
  v_ws_id := case
    when tg_op = 'DELETE' then old.scheduled_workshop_id
    else new.scheduled_workshop_id
  end;
  v_credited_new := case
    when tg_op = 'DELETE' then null
    else new.credited_series_id
  end;
  v_credited_old := case
    when tg_op = 'INSERT' then null
    else old.credited_series_id
  end;

  if v_child_id is null then return null; end if;

  -- Physical series (new side).
  if v_ws_id is not null then
    select coalesce(sw.series_id, sw.recurring_series_id)
      into v_series_id
      from public.scheduled_workshops sw
      where sw.id = v_ws_id;
    if v_series_id is not null then
      v_affected := v_affected || v_series_id;
    end if;
  end if;

  -- Physical series (old side on UPDATE/DELETE if different).
  if tg_op in ('UPDATE', 'DELETE') then
    v_old_ws_id := case tg_op
      when 'UPDATE' then old.scheduled_workshop_id
      when 'DELETE' then old.scheduled_workshop_id
    end;
    if v_old_ws_id is not null and v_old_ws_id is distinct from v_ws_id then
      select coalesce(sw.series_id, sw.recurring_series_id)
        into v_old_series_id
        from public.scheduled_workshops sw
        where sw.id = v_old_ws_id;
      if v_old_series_id is not null then
        v_affected := v_affected || v_old_series_id;
      end if;
    end if;
  end if;

  -- Credited series (new + old).
  if v_credited_new is not null then
    v_affected := v_affected || v_credited_new;
  end if;
  if v_credited_old is not null
     and v_credited_old is distinct from v_credited_new then
    v_affected := v_affected || v_credited_old;
  end if;

  -- Child id change on UPDATE — recalc for OLD child as well.
  if tg_op = 'UPDATE'
     and old.child_id is distinct from new.child_id
     and old.child_id is not null then
    -- Collect series touched by the old row via a recursive call.
    perform public.recalculate_all_child_payment_cycles(old.child_id);
  end if;

  -- De-duplicate + run recalc for each distinct affected series.
  select coalesce(array_agg(distinct u), array[]::uuid[])
    into v_dedup
    from unnest(v_affected) as u
    where u is not null;

  if v_dedup is not null then
    foreach v_s in array v_dedup
    loop
      if v_s is not null then
        perform public.recalculate_child_series_payment_cycles(
          v_child_id, v_s);
      end if;
    end loop;
  end if;

  return null;
end;
$trg$;

-- Trigger definition unchanged; only the function body was rewritten.

-- ── 4b. Double-credit guard: reverse direction (makeup ↔ credit) ─────────
-- The validator above rejects setting credited_series_id on an attendance
-- that is already a makeup destination. The REVERSE direction — creating
-- a makeup_sessions row that targets an attendance which already has
-- credited_series_id — would also double-credit. Only attached if the
-- makeup_sessions table exists (post 20261006). This is additive: it
-- does NOT remove or alter the existing makeup validator; it runs in
-- addition to it.
do $block$
begin
  if to_regclass('public.makeup_sessions') is not null then
    create or replace function public.validate_makeup_vs_credit()
    returns trigger
    language plpgsql
    security definer
    set search_path = public
    as $validate_mvc$
    declare
      v_credited uuid;
    begin
      if new.makeup_attendance_id is null then
        return new;
      end if;
      if coalesce(new.status, 'planned') = 'cancelled' then
        return new;
      end if;
      select credited_series_id into v_credited
        from public.attendance
        where id = new.makeup_attendance_id;
      if v_credited is not null then
        raise exception
          'validate_makeup_vs_credit: attendance % already has '
          'credited_series_id set; cannot additionally link via '
          'makeup_sessions', new.makeup_attendance_id
        using errcode = '23514';
      end if;
      return new;
    end;
    $validate_mvc$;

    revoke all on function public.validate_makeup_vs_credit() from public;

    drop trigger if exists validate_makeup_vs_credit_trg
      on public.makeup_sessions;
    create trigger validate_makeup_vs_credit_trg
      before insert or update of makeup_attendance_id, status
      on public.makeup_sessions
      for each row
      execute function public.validate_makeup_vs_credit();
  end if;
end;
$block$;

-- ── 5. Extend recalculate_all_child_payment_cycles to include visitor ────
-- The 20260820 version only unions physical-series + enrolled-series. A
-- child who has visitor-credited attendance (but no enrollment on the
-- physical series) is already covered via the enrollment union (the
-- credited series IS an enrollment of theirs). This block is kept for
-- parity + future-proofing in case the invariant relaxes.

create or replace function public.recalculate_all_child_payment_cycles(
  p_child_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $all$
declare
  v_series_id uuid;
  v_results jsonb := '[]'::jsonb;
  v_r jsonb;
begin
  for v_series_id in
    select distinct series_id from (
      select coalesce(sw.series_id, sw.recurring_series_id) as series_id
        from public.attendance a
        join public.scheduled_workshops sw on sw.id = a.scheduled_workshop_id
        where a.child_id = p_child_id
      union
      select a.credited_series_id as series_id
        from public.attendance a
        where a.child_id = p_child_id
          and a.credited_series_id is not null
      union
      select we.series_id
        from public.workshop_enrollments we
        where we.child_id = p_child_id and we.is_active = true
    ) u
    where u.series_id is not null
  loop
    v_r := public.recalculate_child_series_payment_cycles(
      p_child_id, v_series_id);
    v_results := v_results || v_r;
  end loop;
  return jsonb_build_object('child_id', p_child_id, 'results', v_results);
end;
$all$;

revoke all on function public.recalculate_all_child_payment_cycles(uuid)
  from public;
grant execute on function public.recalculate_all_child_payment_cycles(uuid)
  to authenticated, service_role;

-- ── 6. Record applied flag ────────────────────────────────────────────────
comment on table public.attendance is
  '20261014: flexible attendance credit added via credited_series_id. '
  'See validate_attendance_credit_trg and '
  'recalculate_child_series_payment_cycles for the credit routing rules.';

commit;

-- ═══════════════════════════════════════════════════════════════════════════
-- ROLLBACK (manual; copy into a separate migration):
--
--   begin;
--   drop trigger if exists validate_attendance_credit_trg on public.attendance;
--   drop function if exists public.validate_attendance_credit();
--   drop index if exists public.attendance_credited_series_idx;
--   alter table public.attendance drop column if exists credited_series_id;
--   -- Restore the recalc + fan-out trigger bodies from 20261006 (recalc)
--   -- and 20260820 (trigger). The 20261006 body is already in the migration
--   -- file at supabase/migrations/20261006_stage3_makeup_sessions.sql
--   -- (section 6); the 20260820 body is at supabase/migrations/
--   -- 20260820_payment_cycles_per_series.sql (section 8).
--   commit;
--
-- ═══════════════════════════════════════════════════════════════════════════
