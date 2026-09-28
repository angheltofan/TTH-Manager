-- ─────────────────────────────────────────────────────────────────────
-- 20260930_afterschool_update_program_rpc — Phase 2 support
-- ─────────────────────────────────────────────────────────────────────
--
-- Introduces one SECURITY DEFINER RPC:
--
--   update_afterschool_program(program_id, name, description,
--     days_of_week, start_time, end_time, monthly_fee, currency,
--     max_capacity, active_from, active_to) → void
--
-- Reason for existence
--   The admin UI must be able to change a program's days_of_week and
--   have the affected active enrollments' attendance_days normalised
--   in the SAME transaction. Without this RPC the two writes would
--   have to happen client-side, which cannot be transactional across
--   PostgREST calls and could orphan attendance_days entries that no
--   longer reference an existing program day.
--
--   The RPC therefore replaces the client-side "PUT programs/:id"
--   whenever the admin edits a program: the client always calls
--   update_afterschool_program(...) and never performs a direct
--   UPDATE on afterschool_programs.
--
-- Contract
--   • SECURITY DEFINER + explicit is_admin() gate.
--   • Explicit, typed parameters (no jsonb patch). Contract is
--     validatable by looking at the signature.
--   • Server is the sole source of truth for the enrollment
--     normalization: any client-side preview is advisory. At commit
--     time, the RPC re-reads the affected enrollments' current
--     attendance_days (still-active rows only) and recomputes the
--     intersection. If any active enrollment would be left with an
--     empty attendance_days, the whole transaction aborts and
--     nothing changes.
--   • Ordering: enrollments are UPDATE-d BEFORE the program row so
--     the existing trigger tg_afs_enr_attendance_days_subset still
--     sees the OLD (wider) days_of_week and validates cleanly. The
--     program UPDATE happens last, once every dependent enrollment
--     is on a subset of the new days.

create or replace function public.update_afterschool_program(
  p_program_id     uuid,
  p_name           text,
  p_description    text,
  p_days_of_week   smallint[],
  p_start_time     time,
  p_end_time       time,
  p_monthly_fee    numeric,
  p_currency       text,
  p_max_capacity   integer,
  p_active_from    date,
  p_active_to      date
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_program      public.afterschool_programs%rowtype;
  v_enrollment   record;
  v_intersection smallint[];
begin
  -- A. Authorization: admin only.
  if not public.is_admin() then
    raise exception 'insufficient_privileges: admin only';
  end if;

  if p_program_id is null then
    raise exception 'invalid_arguments: program_id required';
  end if;

  -- B. Lock the program row (also verifies existence).
  select * into v_program
    from public.afterschool_programs
    where id = p_program_id
    for update;
  if not found then
    raise exception 'program_not_found: %', p_program_id;
  end if;

  -- C. Cheap client-visible validation (heavy validation stays on the
  -- CHECK constraints; these raise clearer errors before we touch any
  -- row).
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'invalid_arguments: name must not be empty';
  end if;
  if p_days_of_week is null or cardinality(p_days_of_week) = 0 then
    raise exception 'invalid_arguments: days_of_week must be non-empty';
  end if;
  if not (p_days_of_week <@ array[1,2,3,4,5,6,7]::smallint[]) then
    raise exception 'invalid_arguments: days_of_week outside 1..7';
  end if;
  if p_start_time is null or p_end_time is null
     or p_end_time <= p_start_time then
    raise exception 'invalid_arguments: end_time must be > start_time';
  end if;
  if p_monthly_fee is null or p_monthly_fee <= 0 then
    raise exception 'invalid_arguments: monthly_fee must be > 0';
  end if;
  if p_currency is null or length(trim(p_currency)) = 0 then
    raise exception 'invalid_arguments: currency must not be empty';
  end if;
  if p_max_capacity is not null and p_max_capacity <= 0 then
    raise exception 'invalid_arguments: max_capacity must be > 0 when set';
  end if;
  if p_active_from is null then
    raise exception 'invalid_arguments: active_from must be provided';
  end if;
  if p_active_to is not null and p_active_to < p_active_from then
    raise exception 'invalid_arguments: active_to must be >= active_from';
  end if;

  -- D. If days_of_week is changing, walk every ACTIVE enrollment with
  -- a non-NULL attendance_days and either normalize or refuse.
  -- Ended/inactive enrollments are ignored, per Phase 2 spec.
  if p_days_of_week is distinct from v_program.days_of_week then
    for v_enrollment in
      select id, attendance_days
      from public.afterschool_enrollments
      where program_id = p_program_id
        and is_active  = true
        and enrolled_until is null
        and attendance_days is not null
      for update
    loop
      -- Compute intersection preserving smallint type and sorted order.
      select array_agg(d order by d)::smallint[]
        into v_intersection
        from (
          select unnest(v_enrollment.attendance_days) as d
          intersect
          select unnest(p_days_of_week)
        ) s;

      if v_intersection is null or cardinality(v_intersection) = 0 then
        raise exception
          'enrollment_would_have_no_days: enrollment=% current=% new_program_days=%',
          v_enrollment.id,
          v_enrollment.attendance_days,
          p_days_of_week;
      end if;

      if v_intersection is distinct from v_enrollment.attendance_days then
        -- The BEFORE UPDATE trigger tg_afs_enr_attendance_days_subset
        -- validates the new value against the CURRENT (old) program
        -- days_of_week, which is guaranteed to be a superset of the
        -- intersection. Safe.
        update public.afterschool_enrollments
          set attendance_days = v_intersection
          where id = v_enrollment.id;
      end if;
    end loop;
  end if;

  -- E. Update the program row.
  update public.afterschool_programs
    set name         = p_name,
        description  = p_description,
        days_of_week = p_days_of_week,
        start_time   = p_start_time,
        end_time     = p_end_time,
        monthly_fee  = p_monthly_fee,
        currency     = p_currency,
        max_capacity = p_max_capacity,
        active_from  = p_active_from,
        active_to    = p_active_to
    where id = p_program_id;
end;
$$;

comment on function public.update_afterschool_program(
  uuid, text, text, smallint[], time, time, numeric, text, integer,
  date, date
) is
  'Atomically updates an Afterschool program and, when days_of_week '
  'narrows, normalizes the attendance_days of every still-active '
  'enrollment with a non-NULL attendance_days by intersecting with '
  'the new program days. Aborts the whole transaction if any '
  'enrollment would be left with zero days — the admin must fix the '
  'affected enrollments first. Admin-only.';

revoke all on function public.update_afterschool_program(
  uuid, text, text, smallint[], time, time, numeric, text, integer,
  date, date
) from public;
grant execute on function public.update_afterschool_program(
  uuid, text, text, smallint[], time, time, numeric, text, integer,
  date, date
) to authenticated;
