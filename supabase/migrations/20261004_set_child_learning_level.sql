-- ─────────────────────────────────────────────────────────────────────
-- 20261004_set_child_learning_level — Phase 2 trainer level editor
-- ─────────────────────────────────────────────────────────────────────
--
-- Goal
--   Phase 2 lets both ADMIN and TRAINER edit the two TTH learning
--   fields on a child:
--     • children.current_level
--     • children.level_progress
--
-- Problem
--   The existing children UPDATE policy is admin-only
--   (children_update_admin, USING is_admin()). Opening a broad
--   trainer UPDATE policy would also let trainers mutate names,
--   payment_type, parent contact and the whole rest of the row —
--   that is more privilege than the product requires.
--
-- Solution
--   A narrow SECURITY DEFINER RPC that writes exactly these two
--   columns (plus updated_at) and nothing else. The function is
--   gated by `public.is_staff()` inside its body, so only admin +
--   trainer can invoke it; parents get a `permission denied`
--   exception. The existing admin-only RLS UPDATE policy stays
--   untouched — admins who want to update other children fields
--   continue to go through the standard path.
--
-- Why not add a trainer RLS UPDATE policy with a WITH CHECK
-- restricted to the two columns?
--   PostgreSQL RLS WITH CHECK cannot restrict WHICH columns a
--   trainer may update inside the same UPDATE statement — it only
--   restricts WHICH rows. A row-scoped trainer policy would still
--   let a trainer craft `UPDATE children SET first_name='pwned'
--   WHERE id=…`. The RPC closes that gap by design.
--
-- Scope — strictly additive
--   • Creates one function, nothing else.
--   • Does NOT modify any policy or constraint.
--   • Does NOT touch any existing row.
--   • Server-side CHECK constraints
--     (children_current_level_check / children_level_progress_check)
--     remain the final gate on value validity; the function raises
--     earlier for a clearer error message.
--
-- Effect matrix
--   caller role         can invoke RPC?       can bypass to other cols?
--   admin               ✓ (via is_staff)      N/A — RPC only writes 2 cols
--   trainer             ✓ (via is_staff)      N/A — RPC only writes 2 cols
--   parent              ✗ (is_staff is false) N/A
--   anon                ✗ (is_staff is false) N/A
--
-- Rollout
--   Called from the Phase 2 Child Details page's new "Parcurs TTH"
--   editor. Clients hand it (child_id, level, progress); the server
--   enforces staff, column scope, value range, and existence.

begin;

create or replace function public.set_child_learning_level(
  p_child_id uuid,
  p_current_level text,
  p_level_progress integer
)
returns public.children
language plpgsql
security definer
set search_path = public
as $func$
declare
  v_row public.children;
begin
  if not public.is_staff() then
    raise exception 'not authorized to update learning level'
      using errcode = '42501';
  end if;

  if p_current_level is not null
     and p_current_level not in
         ('Explorer', 'Builder', 'Programmer', 'Architect') then
    raise exception 'invalid current_level: %', p_current_level
      using errcode = '22P02';
  end if;

  if p_level_progress is not null
     and (p_level_progress < 0 or p_level_progress > 100) then
    raise exception 'level_progress out of range (0..100): %',
      p_level_progress
      using errcode = '22003';
  end if;

  update public.children
    set current_level  = p_current_level,
        level_progress = p_level_progress,
        updated_at     = now()
    where id = p_child_id
    returning * into v_row;

  if not found then
    raise exception 'child not found: %', p_child_id
      using errcode = 'P0002';
  end if;

  return v_row;
end;
$func$;

comment on function public.set_child_learning_level(uuid, text, integer) is
  'Phase 2. Writes children.current_level and children.level_progress '
  'for a single child. Gated by is_staff() so admin + trainer may '
  'call it; parents are refused. SECURITY DEFINER so trainers do not '
  'need a broader children UPDATE policy. The function sets only '
  'these two columns (plus updated_at) — no other field can be '
  'mutated through this surface, by design.';

revoke all on function public.set_child_learning_level(uuid, text, integer)
  from public;

grant execute
  on function public.set_child_learning_level(uuid, text, integer)
  to authenticated;

commit;
