-- ─────────────────────────────────────────────────────────────────────
-- 20261002_parent_portal_phase1 — Parent Portal expansion, Phase 1
-- ─────────────────────────────────────────────────────────────────────
--
-- Infrastructure-only migration for the future "Progres și feedback"
-- feature. No UI code depends on this yet; the trainer feedback
-- workflow and the parent-side rendering ship in Phase 2+ pending
-- explicit approval.
--
-- Scope
--   • child_progress — split the free-text 'note' into three
--     structured fields (built / learned / parent_message), add a
--     uniqueness guarantee per (child, session), tighten the SELECT
--     RLS policy from "any authenticated user" to "staff OR this
--     child's parent", and declare the DELETE gate explicitly as
--     admin-only (previously implicit via no DELETE policy).
--   • children — add two nullable progression fields (current_level,
--     level_progress). Existing children stay NULL/NULL, which the
--     application treats as "not yet placed" rather than falsely
--     implying progress for everyone.
--
-- Pre-flight audit (ran manually before writing this migration)
--   • child_progress is empty in production (0 rows). No duplicate
--     (child_id, scheduled_workshop_id) tuples. No application code
--     writes to the table yet.
--   • children: 48 rows. No existing current_level / level_progress
--     columns.
--   • RLS helpers in use (is_admin, is_staff, is_parent_for_child,
--     is_assigned_trainer) are already SECURITY DEFINER and are the
--     canonical gates used across the schema.
--
-- Non-destructive
--   • No existing column dropped. No existing row deleted or
--     rewritten. No existing constraint relaxed except
--     child_progress.note NOT NULL → NULLABLE (0 rows affected; the
--     constraint blocks the new feedback upsert when the trainer
--     starts from the structured fields rather than the legacy note).
--   • The dropped SELECT policy `read_child_progress_authenticated`
--     is replaced in the same transaction with a stricter one, so
--     the authorized surface strictly contracts, never widens.
--
-- Effect matrix (child_progress) after migration
--   SELECT   admin ✓ (via is_staff) | trainer ✓ (via is_staff) |
--            parent ✓ (via is_parent_for_child(child_id))      |
--            anon ✗ | any_other_authenticated ✗
--   INSERT   admin ✓ | assigned_trainer ✓ | parent ✗ | anon ✗
--   UPDATE   admin ✓ | assigned_trainer ✓ | parent ✗ | anon ✗
--   DELETE   admin ✓ (explicit) | trainer ✗ | parent ✗ | anon ✗
--
-- Follow-ups (NOT in this migration, out of scope)
--   • Phase 2: trainer feedback UI backed by this schema.
--   • The CHECK on child_progress.status still restricts values to
--     'in_progress' / 'completed' / 'needs_review'. Trainers who want
--     to express "no verdict yet, just a message to the parent" can
--     leave the default 'in_progress' in place. Expand only if a
--     real workflow demands it.

begin;

-- ── child_progress: structured feedback fields ─────────────────────────────

alter table public.child_progress
  alter column note drop not null;

comment on column public.child_progress.note is
  'Legacy free-text note. Preserved for backward compatibility. The '
  'future trainer feedback flow writes to built / learned / '
  'parent_message instead, leaving this column NULL.';

alter table public.child_progress
  add column if not exists built           text,
  add column if not exists learned         text,
  add column if not exists parent_message  text;

comment on column public.child_progress.built is
  'Short description of what the child built / worked on in this '
  'workshop session. Nullable: a trainer may skip it.';

comment on column public.child_progress.learned is
  'Short description of what the child learned / practiced in this '
  'workshop session. Nullable: a trainer may skip it.';

comment on column public.child_progress.parent_message is
  'Short trainer message addressed to the parent, surfaced on the '
  'Parent Portal "Progres și feedback" page. Nullable.';

-- ── child_progress: uniqueness per (child, session) ────────────────────────
--
-- Partial unique index — covers only rows attached to a specific
-- session. Rows without a session (free-standing progress notes)
-- stay un-constrained; multiple of those per child are allowed. The
-- index also serves the (child_id, scheduled_workshop_id) equality
-- lookup used by the UPSERT.

create unique index if not exists uq_child_progress_child_session
  on public.child_progress (child_id, scheduled_workshop_id)
  where scheduled_workshop_id is not null;

-- ── child_progress: index for the parent bulk feed ─────────────────────────
--
-- The Parent Portal reads child_progress for a SET of child IDs
-- ordered by created_at desc. (child_id, created_at desc) serves
-- both the IN-list filter and the ordering without a separate sort.
-- The pre-existing idx_child_progress_child becomes a prefix of
-- this index — kept to avoid any unrelated plan regression; it can
-- be dropped in a later cleanup pass once a verified EXPLAIN shows
-- no planner reliance on it.

create index if not exists idx_child_progress_child_created
  on public.child_progress (child_id, created_at desc);

-- ── child_progress RLS: tighten SELECT, declare DELETE ─────────────────────
--
-- The old policy allowed EVERY authenticated user to read every
-- progress row. The new policy restricts reads to staff and to the
-- parent of the child the row concerns (same gate used by
-- children, attendance, payment_cycles).

drop policy if exists read_child_progress_authenticated
  on public.child_progress;

create policy child_progress_select_staff_or_parent
  on public.child_progress
  for select
  using (
    public.is_staff()
    or public.is_parent_for_child(child_id)
  );

comment on policy child_progress_select_staff_or_parent
  on public.child_progress is
  'Admin + trainers (via is_staff) read every row. Parents read '
  'only rows for a child they are linked to in child_parents.';

-- DELETE: previously implicitly denied (no policy existed). Make
-- the admin-only gate explicit so the surface is self-describing.

create policy child_progress_delete_admin
  on public.child_progress
  for delete
  using (public.is_admin());

comment on policy child_progress_delete_admin
  on public.child_progress is
  'Admin-only delete. Trainers cannot remove feedback rows (they '
  'update them in place via the admin_or_trainer_update policy).';

-- ── children: TTH learning progression fields ──────────────────────────────
--
-- Nullable on purpose. A NULL current_level means "not placed yet"
-- and the Parent Portal / admin UI must render accordingly. Avoids
-- back-filling 48 existing children with a false 'Explorer' label.
--
-- Access to these two columns inherits the existing children
-- policies: staff read all; a parent reads only via
-- is_parent_for_child(id). No new policy needed.

alter table public.children
  add column if not exists current_level  text,
  add column if not exists level_progress smallint;

alter table public.children
  drop constraint if exists children_current_level_check;

alter table public.children
  add constraint children_current_level_check
  check (
    current_level is null
    or current_level in ('Explorer', 'Builder', 'Programmer', 'Architect')
  );

alter table public.children
  drop constraint if exists children_level_progress_check;

alter table public.children
  add constraint children_level_progress_check
  check (
    level_progress is null
    or (level_progress between 0 and 100)
  );

comment on column public.children.current_level is
  'TTH learning progression. One of Explorer / Builder / Programmer '
  '/ Architect, or NULL when the child has not been placed yet. '
  'Managed manually by admin; no automatic computation.';

comment on column public.children.level_progress is
  'Percent progress inside the current_level, 0..100. NULL when '
  'the child has not been placed yet. Managed manually by admin.';

commit;
