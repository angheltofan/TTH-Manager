-- ─────────────────────────────────────────────────────────────────────
-- 20261003_parent_portal_phase1_upsert_target — Phase 1 fixup
-- ─────────────────────────────────────────────────────────────────────
--
-- Replace the Phase 1 partial unique INDEX on
-- (child_id, scheduled_workshop_id) WHERE scheduled_workshop_id IS NOT NULL
-- with a full UNIQUE CONSTRAINT on (child_id, scheduled_workshop_id).
--
-- Why
--   PostgREST's upsert emits `ON CONFLICT (col, col) DO UPDATE` without
--   the index predicate. A partial unique index therefore does NOT
--   match the ON CONFLICT specification and the upsert fails with
--   "there is no unique or exclusion constraint matching the ON
--   CONFLICT specification". The future trainer feedback flow relies
--   on an upsert keyed by (child_id, scheduled_workshop_id), so the
--   target must be a plain UNIQUE constraint.
--
-- Semantics are preserved
--   • PostgreSQL's default NULLS DISTINCT behaviour on UNIQUE lets
--     multiple rows with scheduled_workshop_id = NULL coexist for
--     the same child — same effective rule as the partial index.
--   • Rows with a non-null scheduled_workshop_id remain uniquely
--     identified by (child_id, scheduled_workshop_id).
--
-- Non-destructive
--   • child_progress is still empty in production (0 rows). The
--     constraint add succeeds immediately.
--   • The dropped partial index is replaced in the same transaction
--     by an equivalent-or-stricter full constraint, so uniqueness
--     is never relaxed, even for an instant.
--
-- Note on dating
--   File-dated 20261003 for ordering purposes; this project uses
--   date-only migration timestamps and already has a 20261002
--   migration for Phase 1. Logical ordering is "immediately after
--   Phase 1" — no calendar-day semantics.

begin;

drop index if exists public.uq_child_progress_child_session;

alter table public.child_progress
  add constraint uq_child_progress_child_session
  unique (child_id, scheduled_workshop_id);

comment on constraint uq_child_progress_child_session
  on public.child_progress is
  'At most one child_progress row per (child, scheduled_workshop). '
  'NULLs are distinct per SQL default, so multiple sessionless '
  'rows per child remain allowed. Serves the trainer feedback '
  'upsert target and the (child, session) equality lookup.';

commit;
