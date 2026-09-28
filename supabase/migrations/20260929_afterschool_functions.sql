-- ─────────────────────────────────────────────────────────────────────
-- 20260929_afterschool_functions — Afterschool RPCs, Phase 1
-- ─────────────────────────────────────────────────────────────────────
--
-- Five RPCs invoked from the Flutter client, all SECURITY DEFINER with
-- an explicit is_staff() gate at the top. Zero interaction with the
-- workshop system.
--
--   1. generate_afterschool_sessions_window(program, from, to)
--      → materialises missing (program, date) session rows in the
--        window, respecting days_of_week and active_from/to. Idempotent
--        via UNIQUE(program_id, session_date). Returns rows inserted.
--
--   2. close_afterschool_session(session_id, reason?)
--      → flips is_closed=true + captures closed_at/closed_by. UI can
--        also UPDATE directly under RLS; this RPC is the audit-safe
--        entry point.
--
--   3. reopen_afterschool_session(session_id)
--      → reverses (2), clearing all closed_* metadata.
--
--   4. ensure_afterschool_current_month_payment(child, program)
--      → materialises the CURRENT-month row (status=due) if none
--        exists AND the enrollment covers this month. Returns the
--        payment id. Safe to call on every page open.
--
--   5. confirm_afterschool_payment(child, program, year, month,
--                                  payment_method, notes?)
--      → confirms an existing due row OR materialises + confirms a
--        NEW row when (year, month) equals current or next calendar
--        month (the advance flow, capped per Q2). Refuses historical
--        months that don't already exist (they require an explicit
--        admin materialization, deferred to Phase 4). Refuses months
--        beyond current+1.
--
-- All RPCs treat `amount` as an immutable snapshot at row creation.
-- Program fee changes never rewrite historical rows.

-- ═════════════════════════════════════════════════════════════════════
-- 1. generate_afterschool_sessions_window
-- ═════════════════════════════════════════════════════════════════════

create or replace function public.generate_afterschool_sessions_window(
  p_program_id uuid,
  p_from       date,
  p_to         date
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_program        record;
  v_current_date   date;
  v_isodow         int;
  v_inserted       int := 0;
  v_effective_from date;
  v_effective_to   date;
begin
  if not public.is_staff() then
    raise exception 'insufficient_privileges: staff only';
  end if;

  if p_program_id is null or p_from is null or p_to is null then
    raise exception 'invalid_arguments: program_id, from, to are required';
  end if;

  select * into v_program
    from public.afterschool_programs
    where id = p_program_id
      and is_active = true
      and archived_at is null;
  if not found then
    raise exception 'program_not_found_or_inactive: %', p_program_id;
  end if;

  -- Clamp the requested window to the program's active period so the
  -- caller can't accidentally generate sessions before active_from or
  -- after active_to.
  v_effective_from := greatest(p_from, v_program.active_from);
  v_effective_to := case
    when v_program.active_to is null then p_to
    else least(p_to, v_program.active_to)
  end;

  if v_effective_from > v_effective_to then
    return 0;
  end if;

  v_current_date := v_effective_from;
  while v_current_date <= v_effective_to loop
    v_isodow := extract(isodow from v_current_date)::int;
    if v_isodow = any(v_program.days_of_week) then
      insert into public.afterschool_sessions (
        program_id, session_date, start_time, end_time, variant
      ) values (
        p_program_id,
        v_current_date,
        v_program.start_time,
        v_program.end_time,
        'regular'
      )
      on conflict (program_id, session_date) do nothing;
      if found then
        v_inserted := v_inserted + 1;
      end if;
    end if;
    v_current_date := v_current_date + 1;
  end loop;

  return v_inserted;
end;
$$;

comment on function public.generate_afterschool_sessions_window(uuid, date, date) is
  'Idempotently materialises afterschool_sessions rows for one program '
  'over [from, to], filtered by the program''s days_of_week and clamped '
  'to its active period. Never touches existing rows (closed sessions '
  'stay closed).';

revoke all on function public.generate_afterschool_sessions_window(uuid, date, date)
  from public;
grant execute on function public.generate_afterschool_sessions_window(uuid, date, date)
  to authenticated;

-- ═════════════════════════════════════════════════════════════════════
-- 2. close_afterschool_session
-- ═════════════════════════════════════════════════════════════════════

create or replace function public.close_afterschool_session(
  p_session_id uuid,
  p_reason     text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'insufficient_privileges: staff only';
  end if;
  if p_session_id is null then
    raise exception 'invalid_arguments: session_id required';
  end if;

  update public.afterschool_sessions
    set is_closed     = true,
        closed_reason = nullif(trim(coalesce(p_reason, '')), ''),
        closed_by     = auth.uid(),
        closed_at     = now()
    where id = p_session_id;

  if not found then
    raise exception 'session_not_found: %', p_session_id;
  end if;
end;
$$;

comment on function public.close_afterschool_session(uuid, text) is
  'Marks a session as CLOSED. Captures the acting user via auth.uid() '
  'so the closure is auditable. Attendance rows are not touched — the '
  'UI treats CLOSED days as "no attendance expected".';

revoke all on function public.close_afterschool_session(uuid, text) from public;
grant execute on function public.close_afterschool_session(uuid, text) to authenticated;

-- ═════════════════════════════════════════════════════════════════════
-- 3. reopen_afterschool_session
-- ═════════════════════════════════════════════════════════════════════

create or replace function public.reopen_afterschool_session(
  p_session_id uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'insufficient_privileges: staff only';
  end if;
  if p_session_id is null then
    raise exception 'invalid_arguments: session_id required';
  end if;

  update public.afterschool_sessions
    set is_closed     = false,
        closed_reason = null,
        closed_by     = null,
        closed_at     = null
    where id = p_session_id;

  if not found then
    raise exception 'session_not_found: %', p_session_id;
  end if;
end;
$$;

comment on function public.reopen_afterschool_session(uuid) is
  'Reverses close_afterschool_session by clearing every closed_* '
  'field. Existing attendance rows are unaffected.';

revoke all on function public.reopen_afterschool_session(uuid) from public;
grant execute on function public.reopen_afterschool_session(uuid) to authenticated;

-- ═════════════════════════════════════════════════════════════════════
-- 4. ensure_afterschool_current_month_payment
-- ═════════════════════════════════════════════════════════════════════
--
-- Q2 rule + phase-1 payment strategy:
--   • only materialises the CURRENT calendar month
--   • only if the child has an enrollment overlapping the month
--   • amount is snapshotted at insert; program fee changes later do
--     NOT rewrite the row
--   • idempotent: returns the existing id when a row already exists

create or replace function public.ensure_afterschool_current_month_payment(
  p_child_id   uuid,
  p_program_id uuid
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_year          smallint;
  v_month         smallint;
  v_month_start   date;
  v_month_end     date;
  v_payment_id    uuid;
  v_enrollment    record;
  v_program       record;
  v_amount        numeric(10, 2);
begin
  if not public.is_staff() then
    raise exception 'insufficient_privileges: staff only';
  end if;
  if p_child_id is null or p_program_id is null then
    raise exception 'invalid_arguments: child_id and program_id required';
  end if;

  v_year        := extract(year  from current_date)::smallint;
  v_month       := extract(month from current_date)::smallint;
  v_month_start := make_date(v_year, v_month, 1);
  v_month_end   := (v_month_start + interval '1 month' - interval '1 day')::date;

  -- Return existing row if any.
  select id into v_payment_id
    from public.afterschool_monthly_payments
    where child_id   = p_child_id
      and program_id = p_program_id
      and year       = v_year
      and month      = v_month;
  if v_payment_id is not null then
    return v_payment_id;
  end if;

  -- Enrollment must overlap the whole month at least at its boundary.
  select * into v_enrollment
    from public.afterschool_enrollments
    where child_id   = p_child_id
      and program_id = p_program_id
      and is_active  = true
      and enrolled_from <= v_month_end
      and (enrolled_until is null or enrolled_until >= v_month_start)
    order by enrolled_from desc
    limit 1;
  if not found then
    raise exception 'no_enrollment_for_period: %-%',
      v_year, lpad(v_month::text, 2, '0');
  end if;

  select * into v_program
    from public.afterschool_programs
    where id = p_program_id;
  if not found then
    raise exception 'program_not_found: %', p_program_id;
  end if;

  v_amount := coalesce(v_enrollment.custom_monthly_fee, v_program.monthly_fee);

  insert into public.afterschool_monthly_payments (
    child_id, program_id, year, month, amount, currency, status
  ) values (
    p_child_id, p_program_id, v_year, v_month,
    v_amount, v_program.currency, 'due'
  )
  on conflict (child_id, program_id, year, month) do nothing
  returning id into v_payment_id;

  -- If a race made a row between our SELECT and INSERT, fetch its id.
  if v_payment_id is null then
    select id into v_payment_id
      from public.afterschool_monthly_payments
      where child_id   = p_child_id
        and program_id = p_program_id
        and year       = v_year
        and month      = v_month;
  end if;

  return v_payment_id;
end;
$$;

comment on function public.ensure_afterschool_current_month_payment(uuid, uuid) is
  'Materialises the CURRENT-month payment row (status=due) for a '
  '(child, program) if the enrollment covers the month. Idempotent + '
  'race-safe. Never materialises past or future months.';

revoke all on function public.ensure_afterschool_current_month_payment(uuid, uuid)
  from public;
grant execute on function public.ensure_afterschool_current_month_payment(uuid, uuid)
  to authenticated;

-- ═════════════════════════════════════════════════════════════════════
-- 5. confirm_afterschool_payment  (also handles advance flow)
-- ═════════════════════════════════════════════════════════════════════
--
-- Confirms a payment for (child, program, year, month) with a method
-- (POS / OP). Behaviour:
--
--   • row already exists (status = due)
--       → flip to paid, capture paid_at + method + confirmed_by
--   • row already exists (status = paid)
--       → NO-OP (returns existing id, safe to double-click)
--   • row already exists (status = cancelled)
--       → refuse (would rewrite audit trail)
--   • row does NOT exist AND target month = current OR next
--       → materialise (snapshot amount from enrollment/program) AND
--         confirm in the same statement (advance flow)
--   • row does NOT exist AND target month < current
--       → refuse: "historical_month_requires_explicit_materialization"
--       (a separate Phase 4 RPC will handle that path)
--   • row does NOT exist AND target month > current + 1
--       → refuse: "target_month_too_far_in_future"

create or replace function public.confirm_afterschool_payment(
  p_child_id       uuid,
  p_program_id     uuid,
  p_year           smallint,
  p_month          smallint,
  p_payment_method text,
  p_notes          text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_year   smallint;
  v_current_month  smallint;
  v_current_ym     int;
  v_target_ym      int;
  v_payment_id     uuid;
  v_status         text;
  v_enrollment     record;
  v_program        record;
  v_amount         numeric(10, 2);
  v_month_start    date;
  v_month_end      date;
  v_notes_clean    text;
begin
  if not public.is_staff() then
    raise exception 'insufficient_privileges: staff only';
  end if;
  if p_child_id is null or p_program_id is null then
    raise exception 'invalid_arguments: child_id and program_id required';
  end if;
  if p_year is null or p_month is null
     or p_month < 1 or p_month > 12
     or p_year < 2000 or p_year > 2100 then
    raise exception 'invalid_arguments: year/month out of range';
  end if;
  if p_payment_method is null or p_payment_method not in ('pos', 'op') then
    raise exception 'invalid_payment_method: expected pos or op';
  end if;

  v_current_year  := extract(year  from current_date)::smallint;
  v_current_month := extract(month from current_date)::smallint;
  v_current_ym    := v_current_year * 12 + v_current_month;
  v_target_ym     := p_year * 12 + p_month;
  v_notes_clean   := nullif(trim(coalesce(p_notes, '')), '');

  -- Bound the advance window: current or next calendar month only.
  if v_target_ym > v_current_ym + 1 then
    raise exception 'target_month_too_far_in_future';
  end if;

  -- Lock the row if it exists so double-click stays deterministic.
  select id, status
    into v_payment_id, v_status
    from public.afterschool_monthly_payments
    where child_id   = p_child_id
      and program_id = p_program_id
      and year       = p_year
      and month      = p_month
    for update;

  if v_payment_id is null then
    -- Row does not exist. Only allowed for current or next month.
    if v_target_ym < v_current_ym then
      raise exception 'historical_month_requires_explicit_materialization';
    end if;

    v_month_start := make_date(p_year, p_month, 1);
    v_month_end   := (v_month_start + interval '1 month' - interval '1 day')::date;

    select * into v_enrollment
      from public.afterschool_enrollments
      where child_id   = p_child_id
        and program_id = p_program_id
        and is_active  = true
        and enrolled_from <= v_month_end
        and (enrolled_until is null or enrolled_until >= v_month_start)
      order by enrolled_from desc
      limit 1;
    if not found then
      raise exception 'no_enrollment_for_period: %-%',
        p_year, lpad(p_month::text, 2, '0');
    end if;

    select * into v_program
      from public.afterschool_programs
      where id = p_program_id;
    if not found then
      raise exception 'program_not_found: %', p_program_id;
    end if;

    v_amount := coalesce(v_enrollment.custom_monthly_fee, v_program.monthly_fee);

    insert into public.afterschool_monthly_payments (
      child_id, program_id, year, month, amount, currency,
      status, paid_at, payment_method, confirmed_by, notes
    ) values (
      p_child_id, p_program_id, p_year, p_month,
      v_amount, v_program.currency,
      'paid', now(), p_payment_method, auth.uid(), v_notes_clean
    )
    on conflict (child_id, program_id, year, month) do nothing
    returning id into v_payment_id;

    -- Rare race: another transaction inserted between the SELECT above
    -- and this INSERT. Fall through to the "row exists" branch by
    -- re-selecting so the confirm still succeeds.
    if v_payment_id is null then
      select id, status
        into v_payment_id, v_status
        from public.afterschool_monthly_payments
        where child_id   = p_child_id
          and program_id = p_program_id
          and year       = p_year
          and month      = p_month
        for update;
    else
      return v_payment_id;
    end if;
  end if;

  -- Row exists. Idempotent on 'paid', refuse on 'cancelled'.
  if v_status = 'paid' then
    return v_payment_id;
  end if;
  if v_status = 'cancelled' then
    raise exception 'cannot_confirm_cancelled_payment';
  end if;

  update public.afterschool_monthly_payments
    set status         = 'paid',
        paid_at        = now(),
        payment_method = p_payment_method,
        confirmed_by   = auth.uid(),
        notes          = coalesce(v_notes_clean, notes)
    where id = v_payment_id;

  return v_payment_id;
end;
$$;

comment on function public.confirm_afterschool_payment(uuid, uuid, smallint, smallint, text, text) is
  'Confirms a monthly payment for (child, program, year, month). '
  'Materialises + confirms in one call for current or next month '
  '(advance flow). Refuses historical unmaterialized months and any '
  'month beyond current+1. Idempotent on already-paid rows.';

revoke all on function public.confirm_afterschool_payment(uuid, uuid, smallint, smallint, text, text)
  from public;
grant execute on function public.confirm_afterschool_payment(uuid, uuid, smallint, smallint, text, text)
  to authenticated;
