-- ─────────────────────────────────────────────────────────────────────
-- 20261001_afterschool_attendance_delete_staff — Phase 3 support
-- ─────────────────────────────────────────────────────────────────────
--
-- Broaden the DELETE authorization on public.afterschool_attendance
-- from admin-only to staff (admin + trainer).
--
-- Reason
--   Phase 3 introduces the "Astăzi" daily attendance UI. Product
--   decision: trainers must be able to return an attendance mark to
--   UNMARKED (i.e. delete the row) — not only flip present↔absent.
--   The Phase 1 policy `afs_attendance_delete_admin` denied this to
--   trainers; this migration replaces it with a staff-scoped policy.
--
-- Scope
--   • Additive: does NOT touch schema, constraints, RPCs, other
--     Afterschool policies, or any workshop object.
--   • The policy previously named `afs_attendance_delete_admin` is
--     dropped and a new one named `afs_attendance_delete_staff` is
--     created in its place, so the name accurately reflects the gate.
--   • Anonymous callers stay refused (no anon policy). Parents remain
--     refused (no parent DELETE policy).
--
-- Effect matrix after this migration
--   SELECT   staff | parent(c)     — unchanged
--   INSERT   staff                 — unchanged
--   UPDATE   staff                 — unchanged
--   DELETE   staff                 — WIDENED from admin-only to staff

drop policy if exists afs_attendance_delete_admin
  on public.afterschool_attendance;

create policy afs_attendance_delete_staff
  on public.afterschool_attendance
  for delete
  using (public.is_staff());

comment on policy afs_attendance_delete_staff
  on public.afterschool_attendance is
  'Staff (admin + trainer) can DELETE an afterschool_attendance row, '
  'i.e. return a mark to UNMARKED. Phase 3 UX requirement.';
