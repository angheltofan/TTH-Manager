# RLS policies — TTH Manager

**Status:** expected behavior + commented example SQL.
**Companion to:** `docs/database_schema.md`.

> Nothing in this file is executed by the app. All SQL blocks are commented
> examples for manual review and application in Supabase. Do not apply
> blindly — verify against your actual schema and test with each role.

The Flutter client makes role-based UI decisions (`profile.isAdmin`,
`profile.isTrainer` via [`permission_utils.dart`](../lib/core/utils/permission_utils.dart)) but **does not enforce
security**. RLS is the only real defense; the app behaves as if it is in
place.

---

## 1. Roles

| Role | Today (Phase 5) | Future |
|---|---|---|
| `admin` | Full read/write across all staff features. Created manually in Supabase or promoted from `pending` | Unchanged |
| `trainer` | Read all workshops; mark attendance only for own workshops; read/edit own children and series | Unchanged |
| `pending` | Reserved by Phase 1 audit; not yet adopted. New signups would land here pending admin approval | Adopt when public signup is reintroduced |
| `parent` | **Not yet implemented.** Reserved for the future parent-facing app. Would scope reads to their own child(ren) only | Implement when the parent app ships |

Public signup is currently **disabled** (Phase 1). All accounts are created
by an admin via Supabase dashboard. The auth flow is:

1. Admin creates a Supabase auth user.
2. `AuthRepository.getProfile(userId)` reads the corresponding `profiles`
   row. If absent, the user is blocked at the app shell.
3. Role gating happens in [`appRealtimeProvider`](../lib/core/providers/app_realtime_provider.dart):
   `if (profile == null || (!profile.isAdmin && !profile.isTrainer)) return;`

---

## 2. General principles

| Principle | Why |
|---|---|
| **Default-deny.** Every table has `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;` and no policies = no access | Supabase default is to reject when RLS is enabled and no policy matches |
| **`auth.uid()` is the trusted user identity.** Use it on every policy that gates by user | Never trust a client-supplied `recipient_id` / `trainer_id` filter alone |
| **Helper functions are SECURITY DEFINER + STABLE.** The role-check helper (below) should be a function so policies stay readable | Inline `EXISTS (SELECT 1 FROM profiles ...)` works too but repeats. A function lets you change the role model in one place |
| **Realtime obeys RLS.** Each subscribed table needs a `SELECT` policy that matches what the app expects to read; otherwise the channel will silently miss rows | Realtime channels run as the connected user, not as `service_role` |
| **Storage / file uploads** | Not covered here — the app does not currently use Supabase Storage |

### Helper function (recommended)

```sql
-- Returns the role of the caller, or null if no profile row.
-- SECURITY DEFINER so it can read profiles even if the caller doesn't have
-- a direct SELECT policy on it.
CREATE OR REPLACE FUNCTION public.current_role_of(p_user uuid DEFAULT auth.uid())
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = p_user;
$$;

-- Convenience predicates (purely sugar):
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT public.current_role_of() = 'admin';
$$;

CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT public.current_role_of() IN ('admin','trainer');
$$;
```

Test the helper before relying on it:

```sql
-- As an admin user
SELECT public.is_admin(); -- expect true
-- As a trainer
SELECT public.is_admin(); -- expect false
SELECT public.is_staff(); -- expect true
```

---

## 3. Table-by-table expectations

For each table:
- **What admin should do.**
- **What trainer should do.**
- **What parent should eventually do** (parent app not yet shipped).
- **Current code assumption** — what the Flutter client behaves as if it is true.
- **Risk if policy is too open.**
- **Risk if policy is too restrictive.**
- **Example SQL** (commented; for manual review).

### 3.1 `profiles`

| Role | Read | Insert | Update | Delete |
|---|---|---|---|---|
| admin | all rows | all | all | discouraged (use deactivation) |
| trainer | self + other staff (for chat sender names, trainer dropdowns) | none | self only (e.g. name change) | none |
| parent (future) | self only | none | self only | none |

- **Current code assumption:** any signed-in user can read the staff list
  (`TrainersRepository.getAll`, `trainersForDropdownProvider`,
  `profiles!sender_id(...)` joins in team chat).
- **Risk if too open:** admin can be flagged from the client. Email is stored
  in `auth.users`, not `profiles`, so no PII leak from this table — but role
  visibility is a low-grade information leak.
- **Risk if too restrictive:** the trainer dropdown in workshop form and the
  team chat sender names disappear.

```sql
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- SELECT: any signed-in user reads the directory.
CREATE POLICY profiles_select_signed_in
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

-- UPDATE: self only.
CREATE POLICY profiles_update_self
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- INSERT / DELETE: admin only.
CREATE POLICY profiles_admin_write
  ON public.profiles FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
```

### 3.2 `children`

| Role | Read | Insert | Update | Delete |
|---|---|---|---|---|
| admin | all | yes | yes | yes (soft via `is_active`) |
| trainer | children enrolled in own series | no (form gated in UI) | no | no |
| parent (future) | own child only | no | own child basic fields (TBD) | no |

- **Current code assumption:** trainer-side queries do not pass a trainer
  filter — they rely on RLS. `ChildrenRepository.getAllWithWorkshops` and
  `ChildAttendanceRepository.getAllForTrainer` both assume the row set is
  pre-scoped. If RLS is missing, **a trainer sees every child**.
- **Risk if too open:** PII exposure (parent phone, email, notes).
- **Risk if too restrictive:** trainer's children page goes empty even for
  legitimate enrollments.

```sql
ALTER TABLE public.children ENABLE ROW LEVEL SECURITY;

-- SELECT: admin sees all; trainer sees children enrolled in a series they own.
CREATE POLICY children_select_admin
  ON public.children FOR SELECT
  TO authenticated
  USING (public.is_admin());

CREATE POLICY children_select_trainer
  ON public.children FOR SELECT
  TO authenticated
  USING (
    public.current_role_of() = 'trainer'
    AND EXISTS (
      SELECT 1
      FROM public.workshop_enrollments we
      JOIN public.workshop_series ws ON ws.id = we.series_id
      WHERE we.child_id = id
        AND we.is_active = true
        AND ws.trainer_id = auth.uid()
    )
  );

-- INSERT / UPDATE / DELETE: admin only.
CREATE POLICY children_admin_write
  ON public.children FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
```

### 3.3 `workshop_series`

| Role | Read | Insert | Update | Delete |
|---|---|---|---|---|
| admin | all | yes | yes | yes (via deactivation) |
| trainer | own series (and possibly all for demo dropdown) | no | own series (limited fields) | no |
| parent (future) | series their child attends | no | no | no |

- **Current code assumption:** trainer-side queries assume the row set is
  pre-scoped to their own series.
- **Decision needed:** the demo creation dropdown
  (`fetchActiveSeriesForDemo`) reads all active series. If you want trainers
  to see other trainers' series for scheduling demos, keep read open;
  otherwise restrict.

```sql
ALTER TABLE public.workshop_series ENABLE ROW LEVEL SECURITY;

-- SELECT: staff read all (needed for demo dropdown and series search).
CREATE POLICY workshop_series_select_staff
  ON public.workshop_series FOR SELECT
  TO authenticated
  USING (public.is_staff());

-- INSERT / UPDATE: admin always; trainer only their own.
CREATE POLICY workshop_series_admin_write
  ON public.workshop_series FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY workshop_series_trainer_update_own
  ON public.workshop_series FOR UPDATE
  TO authenticated
  USING (
    public.current_role_of() = 'trainer'
    AND trainer_id = auth.uid()
  )
  WITH CHECK (trainer_id = auth.uid());
```

### 3.4 `workshop_enrollments`

| Role | Read | Insert | Update | Delete |
|---|---|---|---|---|
| admin | all | yes | yes | not used (soft via `is_active`) |
| trainer | enrollments for own series | no (Phase 5: admin-only enrollment) | no | no |
| parent (future) | own child's enrollments | no | no | no |

- **Current code assumption:** trainer sees enrollments only for their own
  series. `EnrollmentRepository.enrollChildInWorkshopSeries` is currently
  used by `_AddChildrenButton` which is only shown when `isAdmin` is true,
  but the DB does not enforce that — RLS must.

```sql
ALTER TABLE public.workshop_enrollments ENABLE ROW LEVEL SECURITY;

CREATE POLICY workshop_enrollments_select
  ON public.workshop_enrollments FOR SELECT
  TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.workshop_series ws
      WHERE ws.id = series_id AND ws.trainer_id = auth.uid()
    )
  );

CREATE POLICY workshop_enrollments_admin_write
  ON public.workshop_enrollments FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
```

### 3.5 `scheduled_workshops`

| Role | Read | Insert | Update | Delete |
|---|---|---|---|---|
| admin | all | yes | yes | yes (cancel via `is_active`) |
| trainer | all (need to see colleagues' schedules) | no | only own (e.g. cancel session) | no |
| parent (future) | sessions their child is enrolled in | no | no | no |

- **Current code assumption:** all staff read all schedules. Trainer can
  cancel only their own (`isAdmin` check in UI + RLS enforcement).
- **Risk if too restrictive on read:** dashboard breaks for trainers.

```sql
ALTER TABLE public.scheduled_workshops ENABLE ROW LEVEL SECURITY;

CREATE POLICY scheduled_workshops_select_staff
  ON public.scheduled_workshops FOR SELECT
  TO authenticated
  USING (public.is_staff());

CREATE POLICY scheduled_workshops_admin_write
  ON public.scheduled_workshops FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY scheduled_workshops_trainer_update_own
  ON public.scheduled_workshops FOR UPDATE
  TO authenticated
  USING (
    public.current_role_of() = 'trainer'
    AND trainer_id = auth.uid()
  )
  WITH CHECK (trainer_id = auth.uid());
```

### 3.6 `attendance`

| Role | Read | Insert | Update | Delete |
|---|---|---|---|---|
| admin | all | yes | yes | not used |
| trainer | own workshops' attendance | only for own workshops | only for own workshops | no |
| parent (future) | own child's attendance | no | no | no |

- **Current code assumption:** trainer marks attendance only for own
  workshops. The UI gates this with `canMark = hasRole && canMarkByDate`
  where `hasRole` checks `profile.id == first.trainerId`
  ([`workshop_details_page.dart`](../lib/features/workshops/presentation/workshop_details_page.dart)). **RLS must enforce the same.**
- **Risk if too open:** trainer A marks attendance on trainer B's workshop.
- **Risk if too restrictive:** the central realtime channel can fire but
  the listener can't see the change — the UI looks stuck.

```sql
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

-- Helper expression reused below
-- (admin OR the workshop's trainer)
CREATE POLICY attendance_select_authorized
  ON public.attendance FOR SELECT
  TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.scheduled_workshops sw
      WHERE sw.id = scheduled_workshop_id
        AND sw.trainer_id = auth.uid()
    )
  );

CREATE POLICY attendance_insert_authorized
  ON public.attendance FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.scheduled_workshops sw
      WHERE sw.id = scheduled_workshop_id
        AND sw.trainer_id = auth.uid()
    )
  );

CREATE POLICY attendance_update_authorized
  ON public.attendance FOR UPDATE
  TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.scheduled_workshops sw
      WHERE sw.id = scheduled_workshop_id
        AND sw.trainer_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.scheduled_workshops sw
      WHERE sw.id = scheduled_workshop_id
        AND sw.trainer_id = auth.uid()
    )
  );
```

### 3.7 `payment_cycles`

| Role | Read | Insert | Update | Delete |
|---|---|---|---|---|
| admin | all | yes | yes (confirm payment) | no |
| trainer | cycles for children in own series | no | no (admin-only confirmation) | no |
| parent (future) | own child's cycles | no | no | no |

- **Current code assumption:** the Phase 1/2 audit says payment writes
  should be admin-only. The UI does not gate this — `confirmPayment` and
  `markAdvancePayment` are accessible from `ActiveCycleSection._onConfirm`
  which is reached by any signed-in user. RLS must restrict.

```sql
ALTER TABLE public.payment_cycles ENABLE ROW LEVEL SECURITY;

CREATE POLICY payment_cycles_select_authorized
  ON public.payment_cycles FOR SELECT
  TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.workshop_enrollments we
      JOIN public.workshop_series ws ON ws.id = we.series_id
      WHERE we.child_id = payment_cycles.child_id
        AND ws.trainer_id = auth.uid()
    )
  );

CREATE POLICY payment_cycles_admin_write
  ON public.payment_cycles FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
```

### 3.8 `demo_workshops`

| Role | Read | Insert | Update | Delete |
|---|---|---|---|---|
| admin | all | yes | yes (status, conversion) | no |
| trainer | all (need to see assigned demos) | no | own (mark completed / no_show / cancelled / converted) | no |
| parent (future) | n/a (parent app probably won't see demos) | no | no | no |

- **Current code assumption:** the conversion action (`_convert`) is shown
  only when `isAdmin` ([`_AdminActionsCard`](../lib/features/demo_workshops/presentation/demo_workshop_details_page.dart#L202)). Other status changes
  (`_setStatus`) are also admin-only in the current UI.

```sql
ALTER TABLE public.demo_workshops ENABLE ROW LEVEL SECURITY;

CREATE POLICY demo_workshops_select_staff
  ON public.demo_workshops FOR SELECT
  TO authenticated
  USING (public.is_staff());

CREATE POLICY demo_workshops_admin_write
  ON public.demo_workshops FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Optional: let the assigned trainer mark status changes (NOT conversion).
-- Pair with a CHECK on which columns may be updated if you want to be strict.
CREATE POLICY demo_workshops_trainer_status_update
  ON public.demo_workshops FOR UPDATE
  TO authenticated
  USING (
    public.current_role_of() = 'trainer'
    AND trainer_id = auth.uid()
  )
  WITH CHECK (trainer_id = auth.uid());
```

### 3.9 `notifications`

| Role | Read | Insert | Update | Delete |
|---|---|---|---|---|
| admin | own | only via RPCs (`generate_daily_notifications`) | own (mark as read) | not used |
| trainer | own | none | own (mark as read) | not used |
| parent (future) | own | none | own | not used |

- **Current code assumption:** `fetchNotifications(userId)` filters by
  `recipient_id = userId`. Without RLS, a malicious client could request
  someone else's notifications.

```sql
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifications_select_recipient
  ON public.notifications FOR SELECT
  TO authenticated
  USING (recipient_id = auth.uid());

CREATE POLICY notifications_update_recipient
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());

-- INSERT is performed only via the SECURITY DEFINER RPC
-- `generate_daily_notifications()`. Clients should not insert directly.
CREATE POLICY notifications_no_client_insert
  ON public.notifications FOR INSERT
  TO authenticated
  WITH CHECK (false);
```

### 3.10 `team_chat_messages`

| Role | Read | Insert | Update | Delete (soft) |
|---|---|---|---|---|
| admin | all non-deleted | own | own (edit, if added) | own + any other (moderation) |
| trainer | all non-deleted | own | own | own only |
| parent (future) | n/a | no | no | no |

- **Current code assumption:** chat is staff-only. `TeamChatRepository.softDeleteMessage` does **not** verify the caller is the sender — RLS must.

```sql
ALTER TABLE public.team_chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY team_chat_select_staff
  ON public.team_chat_messages FOR SELECT
  TO authenticated
  USING (public.is_staff());

CREATE POLICY team_chat_insert_own
  ON public.team_chat_messages FOR INSERT
  TO authenticated
  WITH CHECK (sender_id = auth.uid());

-- Sender can soft-delete their own message; admin can soft-delete any.
CREATE POLICY team_chat_softdelete
  ON public.team_chat_messages FOR UPDATE
  TO authenticated
  USING (sender_id = auth.uid() OR public.is_admin())
  WITH CHECK (sender_id = auth.uid() OR public.is_admin());
```

---

## 4. Risks summary

| Severity | Risk | Where |
|---|---|---|
| HIGH | Trainer sees every child if `children` SELECT is unrestricted | section 3.2 |
| HIGH | Trainer marks attendance on someone else's workshop if `attendance` is unrestricted | section 3.6 |
| HIGH | Anyone confirms a payment without admin check if `payment_cycles` is unrestricted on UPDATE | section 3.7 |
| HIGH | User reads another user's notifications | section 3.9 |
| MEDIUM | User soft-deletes someone else's chat message | section 3.10 |
| MEDIUM | Trainer modifies someone else's `workshop_series` or `scheduled_workshops` | sections 3.3, 3.5 |
| MEDIUM | Demo conversion misuse — non-admin marks a demo as "converted" | section 3.8 |
| LOW | Profile directory leaks roles to all signed-in users | section 3.1 |

---

## 5. Verification checklist

After applying policies, run each of the following as the relevant role
(use Supabase's "Run as user" feature):

1. **As a trainer who owns series S1:**
   - `SELECT * FROM children` → only children enrolled in S1
   - `INSERT INTO attendance (...)` for a workshop in S1 → succeeds
   - `INSERT INTO attendance (...)` for a workshop NOT in S1 → fails with
     `permission denied`
   - `UPDATE payment_cycles SET status='paid' WHERE id=...` → fails

2. **As a trainer who owns nothing:**
   - `SELECT * FROM children` → empty
   - `SELECT * FROM workshop_enrollments` → empty

3. **As an admin:**
   - All of the above succeed
   - `SELECT * FROM payment_cycles` returns everything

4. **As an unauthenticated user (anon key):**
   - Every table returns empty / permission denied

5. **Realtime:**
   - Connect a trainer client and subscribe to `attendance`. Mark attendance
     for the trainer's workshop from another device. Confirm the event
     arrives.
   - Mark attendance on a *different* trainer's workshop. Confirm the event
     does **not** arrive.

---

*End of rls_policies.md*
