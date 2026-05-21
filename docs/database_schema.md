# Database schema — TTH Manager

**Status:** source of truth for the current application state (Phase 5).
This file replaces the older sparse description that pre-dated
`workshop_series`, `workshop_enrollments`, `payment_cycles`, `demo_workshops`,
and `team_chat_messages`.

**Scope:** documents what the Flutter app currently queries against. Items not
proven from code are marked **NEEDS DB VERIFICATION**. Nothing in this file is
executed automatically — it is a reference, plus a list of recommendations for
manual SQL review.

**Companion docs:**
- `docs/rls_policies.md` — Row-Level Security expectations.
- `docs/notification_lifecycle.md` — expiry / `expires_at` proposal.
- `docs/demo_conversion_atomicity.md` — `convert_demo_to_enrollment` RPC proposal.

---

## 1. Conventions

| Convention | Value |
|---|---|
| Primary keys | `uuid`, defaulted to `gen_random_uuid()` (assumed unless verified) |
| Timestamps | `timestamptz` for moments (`created_at`, `marked_at`, `paid_at`, …) |
| Dates | `date` for calendar days (`workshop_date`, `birth_date`, `period_start`/`period_end`, `demo_date`) |
| Times | `time` for time-of-day (`start_time`, `end_time`) |
| Soft delete (most tables) | `is_active boolean` |
| Soft delete (attendance) | `is_archived boolean` |
| Soft delete (team_chat_messages) | `is_deleted boolean` |
| Status field | `text` with enum-like values, validated in app code (no DB CHECK constraint proven) |
| Language | UI in Romanian; column names and identifiers in English (per `docs/build_rules.md`) |

> The mixed soft-delete column names (`is_active` vs `is_archived` vs `is_deleted`)
> is a known inconsistency flagged by the audit. Documented here, not yet
> fixed — out of Phase 5 scope.

---

## 2. Tables actually used by the app

11 tables. Each entry lists columns observed in code, FKs proven from code,
soft-delete column if any, the Flutter repository (or repositories) that
touch the table, and whether it is subscribed by `appRealtimeProvider`.

### 2.1 `profiles`

User profiles, one row per Supabase auth user, role-gated.

| Column | Type | Nullable | Notes |
|---|---|:---:|---|
| `id` | uuid | no | PK; FK → `auth.users.id` (proven from `AuthRepository.signUp` upsert) |
| `first_name` | text | no |  |
| `last_name` | text | no |  |
| `role` | text | no | Values used in code: `'admin'`, `'trainer'`. App enforces this set; no DB CHECK proven |
| `created_at` | timestamptz | NEEDS DB VERIFICATION | Read by `TrainersRepository.getAll/getById` |
| `updated_at` | timestamptz | NEEDS DB VERIFICATION | Read by `TrainersRepository.getAll/getById` |

- **Primary key:** `id`.
- **Foreign keys:** `id → auth.users.id`.
- **Soft delete:** none. Deactivation pattern not used; role change is the only state mutation.
- **Flutter consumers:** `AuthRepository`, `TrainersRepository`, joined into many other selects via `profiles!trainer_id(...)` / `profiles!sender_id(...)` / `profiles!marked_by(...)`.
- **Realtime:** **NO** (not subscribed by `appRealtimeProvider`).

---

### 2.2 `children`

Children (students) tracked by the school.

| Column | Type | Nullable | Notes |
|---|---|:---:|---|
| `id` | uuid | no | PK |
| `first_name` | text | no |  |
| `last_name` | text | no |  |
| `birth_date` | date | yes | Used for birthday notification trigger. Optional in form |
| `age` | integer | yes | Stored alongside `birth_date`; not auto-derived in code |
| `parent_name` | text | yes |  |
| `parent_phone` | text | yes | Used by `DemoWorkshopsRepository.findExistingChild` |
| `parent_email` | text | yes | Reserved for future parent app integration; not currently used in UI |
| `notes` | text | yes |  |
| `is_active` | boolean | yes | Soft-delete flag. Default `true` assumed |
| `created_at` | timestamptz | no |  |
| `updated_at` | timestamptz | no |  |

- **Primary key:** `id`.
- **Foreign keys:** none from this table outward; many tables FK to it.
- **Soft delete:** `is_active`.
- **Flutter consumers:** `ChildrenRepository`, `ChildDetailsRepository`, `ChildAttendanceRepository`, `DemoWorkshopsRepository.findExistingChild` / `createChild`.
- **Realtime:** **YES** (channel `rt:children` in `app_realtime_provider.dart`).

---

### 2.3 `scheduled_workshops`

A concrete workshop session occurring on a specific date. Recurring sessions
link back to `workshop_series.id` via `recurring_series_id`.

| Column | Type | Nullable | Notes |
|---|---|:---:|---|
| `id` | uuid | no | PK |
| `title` | text | no |  |
| `workshop_type` | text | no | E.g. "Robotica", "Programare" |
| `workshop_date` | date | no | Local-Bucharest date intended; **no timezone column** |
| `day_of_week` | text | no | Romanian weekday string ("LUNI" / "MARTI" / …) |
| `start_time` | time | no |  |
| `end_time` | time | no |  |
| `trainer_id` | uuid | no | FK → `profiles.id` |
| `notes` | text | yes |  |
| `is_recurring` | boolean | no | When `true`, `recurring_series_id` must be set (post-Phase-3 invariant) |
| `recurring_series_id` | uuid | yes | FK → `workshop_series.id`. Nullable for one-off sessions. NEEDS DB VERIFICATION that the column name is exactly `recurring_series_id` and that the FK constraint exists |
| `is_active` | boolean | no | Soft-delete flag |
| `created_at` | timestamptz | no |  |
| `updated_at` | timestamptz | no |  |

- **Primary key:** `id`.
- **Foreign keys:** `trainer_id → profiles.id`, `recurring_series_id → workshop_series.id` (NEEDS DB VERIFICATION).
- **Soft delete:** `is_active`. Used by `WorkshopsRepository.cancelSession`.
- **Flutter consumers:** `WorkshopsRepository`, `DashboardRepository`, `TrainersRepository.fetchWorkshopsByTrainer`, `EnrollmentRepository._ensureSeriesExists` (reads metadata).
- **Realtime:** **YES** (channel `rt:scheduled_workshops`).
- **Generation:** RPC `generate_recurring_workshops_for_week(p_week_start)` materialises week instances from `workshop_series`.

---

### 2.4 `workshop_series`

Permanent recurring schedule template (e.g. "Robotica, Marți 18:00 with Andrei").
Source of truth for what `scheduled_workshops` rows get generated weekly.

| Column | Type | Nullable | Notes |
|---|---|:---:|---|
| `id` | uuid | no | PK |
| `title` | text | no |  |
| `workshop_type` | text | yes | NEEDS DB VERIFICATION for nullability (code treats as `String?`) |
| `day_of_week` | text | yes | NEEDS DB VERIFICATION |
| `start_time` | time | no | Read as plain string |
| `end_time` | time | yes | NEEDS DB VERIFICATION (code treats as `String?`) |
| `trainer_id` | uuid | yes | FK → `profiles.id`. Nullable: trainer can be unassigned |
| `notes` | text | yes |  |
| `is_active` | boolean | no | Soft-delete flag |
| `created_at` | timestamptz | NEEDS DB VERIFICATION |  |
| `updated_at` | timestamptz | NEEDS DB VERIFICATION |  |

- **Primary key:** `id`.
- **Foreign keys:** `trainer_id → profiles.id`.
- **Soft delete:** `is_active`. Used by `EnrollmentRepository.deactivateSeries`.
- **Flutter consumers:** `EnrollmentRepository`, `DemoWorkshopsRepository.fetchActiveSeriesForDemo`, `TrainersRepository.fetchTrainerSeries`, `WorkshopsRepository.create/update/updateSeries` (upsert).
- **Realtime:** **YES** (channel `rt:workshop_series`).
- **Note:** since Phase 3, `WorkshopsRepository.create()` and `update()` both upsert a `workshop_series` row whenever the scheduled workshop is flipped to recurring. `EnrollmentRepository._ensureSeriesExists()` backfills missing series rows on enrollment if a legacy `scheduled_workshops` row had only `recurring_series_id` set without a matching series.

---

### 2.5 `workshop_enrollments`

Junction table: which children are enrolled in which workshop series.
Replaces the legacy `workshop_children` table.

| Column | Type | Nullable | Notes |
|---|---|:---:|---|
| `id` | uuid | no | PK |
| `child_id` | uuid | no | FK → `children.id` |
| `series_id` | uuid | no | FK → `workshop_series.id` |
| `is_active` | boolean | no | Soft-delete flag. Default `true` |
| `enrolled_by` | uuid | yes | FK → `profiles.id`. Written by `DemoWorkshopsRepository.enrollChild`. NEEDS DB VERIFICATION that this column exists |
| `enrolled_at` | timestamptz | yes | Written by `DemoWorkshopsRepository.enrollChild`. NEEDS DB VERIFICATION |
| `created_at` | timestamptz | NEEDS DB VERIFICATION |  |
| `updated_at` | timestamptz | NEEDS DB VERIFICATION |  |

- **Primary key:** `id`.
- **Foreign keys:** `child_id → children.id`, `series_id → workshop_series.id`.
- **Unique constraint:** `(child_id, series_id)` — proven from `DemoWorkshopsRepository.enrollChild` using `onConflict: 'child_id,series_id'` and from `EnrollmentRepository.enrollChildInWorkshopSeries` catching PostgrestException `23505` (unique violation) and falling back to UPDATE.
- **Soft delete:** `is_active`. Removal sets `is_active=false`, not DELETE.
- **Flutter consumers:** `EnrollmentRepository`, `DemoWorkshopsRepository.enrollChild`, `WorkshopsRepository.getDetails` (joins).
- **Realtime:** **YES** (channel `rt:workshop_enrollments`).

---

### 2.6 `attendance`

One row per `(scheduled_workshop_id, child_id)` pair, recording whether the
child attended that specific occurrence.

| Column | Type | Nullable | Notes |
|---|---|:---:|---|
| `id` | uuid | no | PK |
| `scheduled_workshop_id` | uuid | no | FK → `scheduled_workshops.id` |
| `child_id` | uuid | no | FK → `children.id` |
| `status` | text | no | Values used: `'present'`, `'absent'`, `'motivated'`. Only present/absent are settable from the current UI — `motivated` is a schema-only status with no UI control |
| `observation` | text | yes |  |
| `marked_by` | uuid | no | FK → `profiles.id` |
| `marked_at` | timestamptz | no |  |
| `is_archived` | boolean | no | Soft-delete flag (different name from other tables). Default `false`. Filtered out by `ChildDetailsRepository.fetchChildCurrentStatusRows` |
| `payment_cycle_id` | uuid | yes | FK → `payment_cycles.id`. **Set to a cycle id when a row is "consumed" by a closed cycle**; `NULL` means the row belongs to the still-open current cycle |

- **Primary key:** `id`.
- **Foreign keys:** `scheduled_workshop_id → scheduled_workshops.id`, `child_id → children.id`, `marked_by → profiles.id`, `payment_cycle_id → payment_cycles.id`.
- **Unique constraint:** `(scheduled_workshop_id, child_id)` — proven from `WorkshopsRepository.markAttendance` / `markAllPresent` using `onConflict: 'scheduled_workshop_id,child_id'`.
- **Soft delete:** `is_archived`.
- **Flutter consumers:** `WorkshopsRepository.markAttendance/markAllPresent`, `ChildDetailsRepository.fetchChildCurrentStatusRows`, `ChildAttendanceRepository.getAttendanceHistoryFull/getAttendanceHistoryForTrainerFull`.
- **Realtime:** **YES** (channel `rt:attendance`).
- **Cycle closure (server-side, NEEDS DB VERIFICATION):** the app assumes a trigger (or RPC) closes a `payment_cycles` row at 4 presents by setting `attendance.payment_cycle_id` on the 4 attendance rows and inserting `payment_cycles(status='due', sessions_count=4)`. **The trigger is not in the Flutter code base**; the Phase 3 fix in `payment_status_card.dart` defends against the case where this trigger leaves attendance rows unlinked.

---

### 2.7 `payment_cycles`

Authoritative payment state. One row per 4-session cycle per child, plus
optional advance-payment rows.

| Column | Type | Nullable | Notes |
|---|---|:---:|---|
| `id` | uuid | no | PK |
| `child_id` | uuid | no | FK → `children.id` |
| `period_start` | date | yes | NEEDS DB VERIFICATION for nullability; code treats as `DateTime?` |
| `period_end` | date | yes |  |
| `sessions_count` | integer | yes | Number of attended sessions in the cycle. App assumes 4 = "full cycle" |
| `status` | text | yes | Values used: `'paid'`, `'due'`, `'overdue'`, `'cancelled'`, `'paid_advance'` |
| `paid_at` | timestamptz | yes |  |
| `confirmed_by` | uuid | yes | FK → `profiles.id` |
| `payment_method` | text | yes | Values used: `'pos'`, `'op'`. Falls back to inferring from `notes` |
| `notes` | text | yes | Legacy storage for `'POS'` / `'OP'` (since superseded by `payment_method`) |
| `created_at` | timestamptz | yes |  |
| `updated_at` | timestamptz | NEEDS DB VERIFICATION |  |

- **Primary key:** `id`.
- **Foreign keys:** `child_id → children.id`, `confirmed_by → profiles.id`.
- **Soft delete:** none in the conventional sense; `status='cancelled'` plays that role.
- **Flutter consumers:** `ChildDetailsRepository.confirmPayment/markAdvancePayment/fetchPaymentCycles`, `ChildAttendanceRepository.markPaymentCyclePaid`, `PaymentsDueRepository.getPaymentsDue`, `DashboardRepository.getStats` (direct count by status).
- **Realtime:** **YES** (channel `rt:payment_cycles`).

---

### 2.8 `payments` — **LEGACY / SCHEDULED FOR FUTURE REMOVAL**

Older payment table superseded by `payment_cycles`. Retained because legacy
rows may still be present in production and because one read path still hits
the table.

| Column | Type | Nullable | Notes |
|---|---|:---:|---|
| `id` | uuid | no | PK |
| `child_id` | uuid | no | FK → `children.id` |
| `amount` | numeric | yes |  |
| `currency` | text | yes |  |
| `status` | text | yes | `'paid'`, `'due'`, `'overdue'`, `'cancelled'` |
| `sessions_count` | integer | yes |  |
| `due_reason` | text | yes |  |
| `paid_at` | timestamptz | yes |  |
| `confirmed_by` | uuid | yes | FK → `profiles.id` |
| `notes` | text | yes |  |
| `created_at` | timestamptz | yes |  |
| `updated_at` | timestamptz | yes |  |

- **Why it still exists:** the table may hold historical rows created before
  `payment_cycles` became the active model. Removing it now risks losing
  audit data.
- **Current Flutter consumer:** [`ChildAttendanceRepository.getPayments(childId)`](../lib/features/children/data/child_attendance_repository.dart) (line 166-174). Reads
  `id, amount, currency, status, sessions_count, due_reason, paid_at, notes, created_at`. The provider that calls it is `childPaymentsProvider` in
  [`children_providers.dart`](../lib/features/children/providers/children_providers.dart) — this is a `FutureProvider.family` that returns the legacy list. **Verify whether any UI surface actually reads `childPaymentsProvider` today** before removal.
- **Why `payment_cycles` is now authoritative:** all current pages (Status plată, Plăți restante, dashboard stats) read `payment_cycles` or one of its views (`child_payment_status_rows`, `child_payment_cycles`). The cycle model captures session count + period + status + confirmation, which the older flat `payments` rows did not.
- **Migration/removal recommendation (future phase, NOT Phase 5):**
  1. Audit whether `childPaymentsProvider` has any UI consumer. If not, drop the provider and `getPayments(childId)` repository method first.
  2. Optionally back-fill any meaningful legacy `payments` rows into `payment_cycles` (one-time migration script).
  3. Drop `payments` table.
- **Realtime:** **NO** (not subscribed).

---

### 2.9 `demo_workshops`

Free trial / introduction sessions for prospective enrolments. Distinct
flow from `scheduled_workshops`.

| Column | Type | Nullable | Notes |
|---|---|:---:|---|
| `id` | uuid | no | PK |
| `child_first_name` | text | no | Stored on the demo row, not in `children` (child may not exist yet) |
| `child_last_name` | text | no |  |
| `parent_name` | text | yes |  |
| `parent_phone` | text | yes |  |
| `parent_email` | text | yes |  |
| `workshop_type` | text | no | Copied from selected series at create time |
| `workshop_title` | text | no | Copied from selected series at create time |
| `demo_date` | date | no |  |
| `start_time` | time | no |  |
| `end_time` | time | no |  |
| `trainer_id` | uuid | no | FK → `profiles.id`. Copied from selected series |
| `notes` | text | yes |  |
| `status` | text | no | `'scheduled'`, `'completed'`, `'no_show'`, `'cancelled'`, `'converted'` |
| `converted_child_id` | uuid | yes | FK → `children.id`. Set after successful conversion |
| `converted_series_id` | uuid | yes | FK → `workshop_series.id`. Set after successful conversion |
| `created_by` | uuid | yes | FK → `profiles.id` |
| `created_at` | timestamptz | yes |  |
| `updated_at` | timestamptz | yes | Written by `DemoWorkshopsRepository.update/updateStatus/markConverted` |

- **Primary key:** `id`.
- **Foreign keys:** `trainer_id → profiles.id`, `converted_child_id → children.id`, `converted_series_id → workshop_series.id`, `created_by → profiles.id`.
- **Soft delete:** none in the conventional sense; `status='cancelled'` plays that role.
- **Flutter consumers:** `DemoWorkshopsRepository`.
- **Realtime:** **YES** (channel `rt:demo_workshops`).
- **Notable observation — no `series_id` at creation:** the form stores `workshop_type`, `workshop_title`, and `trainer_id` from the picked series, but **does not persist a `series_id` FK**. The link back to the series is reconstructed only on conversion (`converted_series_id`). Phase 3 added a workshop-type-based filter in `_SelectSeriesDialog` to compensate during conversion.
- **Possible future improvement (Phase 6 candidate, NOT in this phase):**
  ```sql
  -- Add a direct FK so the conversion dialog can default to the exact series
  -- the demo was created from, instead of filtering by workshop_type.
  ALTER TABLE public.demo_workshops
    ADD COLUMN IF NOT EXISTS series_id uuid
      REFERENCES public.workshop_series(id);
  ```
  Not implemented.

---

### 2.10 `team_chat_messages`

Internal staff chat. Soft-deleted via `is_deleted=true`.

| Column | Type | Nullable | Notes |
|---|---|:---:|---|
| `id` | uuid | no | PK |
| `sender_id` | uuid | no | FK → `profiles.id` |
| `body` | text | no |  |
| `is_deleted` | boolean | no | Soft-delete flag. Default `false` |
| `created_at` | timestamptz | no |  |
| `updated_at` | timestamptz | NEEDS DB VERIFICATION (not read by code) |  |

- **Primary key:** `id`.
- **Foreign keys:** `sender_id → profiles.id`.
- **Soft delete:** `is_deleted`.
- **Flutter consumers:** `TeamChatRepository`.
- **Realtime:** **YES** — but **NOT** subscribed by `appRealtimeProvider`. A separate `teamChatRealtimeProvider` in [`team_chat_providers.dart`](../lib/features/team_chat/providers/team_chat_providers.dart) handles it. This is a known inconsistency flagged by the audit, intentionally left for a later phase to consolidate.
- **Local-only state:** the per-user "last read at" timestamp is stored in SharedPreferences ([`_ChatLastReadAtNotifier`](../lib/features/team_chat/providers/team_chat_providers.dart)), so unread badges do **not** sync across devices.

---

### 2.11 `notifications`

In-app notifications. Generated by RPCs/triggers; consumed by the bell and
the full notifications page.

| Column | Type | Nullable | Notes |
|---|---|:---:|---|
| `id` | uuid | no | PK |
| `title` | text | no | Currently inspected for birthday detection (`startsWith('zi de na')`) |
| `body` | text | no |  |
| `type` | text | yes | `'info'`, `'payment'`, `'attendance'`, `'material'`, `'schedule'` |
| `recipient_id` | uuid | no | FK → `profiles.id` |
| `is_read` | boolean | no | Default `false`. Toggled by `NotificationsRepository.markAsRead` / `markAllAsRead` |
| `related_child_id` | uuid | yes | FK → `children.id` |
| `related_workshop_id` | uuid | yes | FK → `scheduled_workshops.id` |
| `created_at` | timestamptz | no |  |
| `action_url` | text | yes | NEEDS DB VERIFICATION — read by `AppNotification.fromMap` |
| `priority` | text | yes | NEEDS DB VERIFICATION — `'high'` / `'normal'` / `'low'` |

- **Primary key:** `id`.
- **Foreign keys:** `recipient_id → profiles.id`, `related_child_id → children.id`, `related_workshop_id → scheduled_workshops.id`.
- **Soft delete:** none. Day-specific notifications (birthdays) are filtered client-side; see `docs/notification_lifecycle.md` for the proposed `expires_at` future state.
- **Flutter consumers:** `NotificationsRepository`.
- **Realtime:** **YES** (channel `rt:notifications`).

---

## 3. Tables defined in the OLD schema doc but not used by Flutter code

These tables appeared in the previous `database_schema.md`. They are **not
queried by any current repository**. They may still exist in the database
(NEEDS DB VERIFICATION) but should be considered stale from the Flutter
side.

| Table | Status |
|---|---|
| `workshop_children` | **REPLACED** by `workshop_enrollments`. No code reference. Should be dropped after verifying no historical data is needed |
| `lesson_materials` | No code reference. Future-feature placeholder; unknown if present in DB |
| `child_progress` | No code reference. Future-feature placeholder; unknown if present in DB |
| `workshops`, `groups`, `enrollments`, `sessions` | Already flagged as forbidden in `docs/build_rules.md`. No code reference |

---

## 4. Views

The app reads from views in addition to base tables. All views below are
queried somewhere in `lib/features/*/data/`. Internal SQL definitions live in
the database — not in this repository.

| View | Used by (file:line) | Notes |
|---|---|---|
| `dashboard_stats` | [`DashboardRepository.getStats`](../lib/features/dashboard/data/dashboard_repository.dart#L14) | Aggregates totals: `total_children`, `workshops_today`, `attendance_rate`. The `pending_payments` field of this view is **overridden in Dart** by a direct count of `payment_cycles` with status in `('due','overdue')` (line 17-23) |
| `dashboard_workshops` | [`DashboardRepository.getTodayWorkshops/getAllScheduledWorkshops`](../lib/features/dashboard/data/dashboard_repository.dart#L29), `WorkshopsRepository.getAllWorkshops` | Columns: `id, title, workshop_type, workshop_date, day_of_week, start_time, end_time, trainer_id, trainer_name, children_count`. **Day-of-week order from the view is alphabetic** (Romanian: JOI < LUNI < MARTI…); Dart re-sorts by `workshop_date` (`workshops_repository.dart:28-32`) |
| `workshop_details` | [`ChildrenRepository.getRowById`](../lib/features/children/data/children_repository.dart#L121), [`ChildAttendanceRepository.getAllForTrainer`](../lib/features/children/data/child_attendance_repository.dart#L45) | Per child + per workshop join with attendance. Columns referenced in code: `child_id, attendance_status, workshop_date, trainer_id` |
| `child_latest_attendance` | [`ChildrenRepository.getAllWithWorkshops`](../lib/features/children/data/children_repository.dart#L63) | **Added Phase 1.** One row per child with latest attendance (`DISTINCT ON child_id ORDER BY workshop_date DESC, marked_at DESC`). Columns: `child_id, status, marked_at, workshop_date, workshop_title, workshop_type` |
| `child_current_status` | [`ChildDetailsRepository.fetchChildCurrentStatus`](../lib/features/children/data/child_details_repository.dart#L36) | Per-child active-cycle summary. Code consumes `sessions_count`. Other columns NEEDS DB VERIFICATION |
| `child_current_status_rows` | (none — bypassed) | **DEFINED but BYPASSED.** Source comment in [`ChildDetailsRepository.fetchChildCurrentStatusRows`](../lib/features/children/data/child_details_repository.dart#L43-L47): _"This bypasses the child_current_status_rows view which may apply a date filter and miss older sessions still in the current open cycle."_ The repo queries `attendance` directly instead. Keep or drop is a DB-side decision |
| `child_payment_status_rows` | [`ChildDetailsRepository.fetchChildPaymentStatusRows`](../lib/features/children/data/child_details_repository.dart#L94), [`PaymentsDueRepository.getPaymentsDue`](../lib/features/payments_due/data/payments_due_repository.dart#L59) | Per attendance row joined with its `payment_cycle` context. Columns referenced: `child_id, cycle_id, workshop_title, workshop_date, day_of_week, start_time, end_time, attendance_status, observation, period_start, period_end, cycle_status, paid_at, confirmed_by_name` |
| `child_payment_cycles` | [`ChildAttendanceRepository.getPaymentCycles`](../lib/features/children/data/child_attendance_repository.dart#L150) | Per-child cycle list. Columns NEEDS DB VERIFICATION; consumed as raw `Map<String, dynamic>` |
| `child_activity_history` | [`ChildAttendanceRepository.getActivityHistory`](../lib/features/children/data/child_attendance_repository.dart#L111) | Per-child activity feed. Columns referenced in code: `child_id, is_archived, workshop_date`. Other columns NEEDS DB VERIFICATION |
| `child_current_cycle_summary` | [`ChildAttendanceRepository.getCurrentCycleSummary`](../lib/features/children/data/child_attendance_repository.dart#L127) | Per-child summary of the currently-open cycle. Columns NEEDS DB VERIFICATION |
| `child_current_cycle_activity` | [`ChildAttendanceRepository.getCurrentCycleActivity`](../lib/features/children/data/child_attendance_repository.dart#L138) | Per-child rows of the currently-open cycle. Columns referenced: `child_id, workshop_date`. Other columns NEEDS DB VERIFICATION |

---

## 5. Functions / RPCs

Three RPCs are called from Flutter. **Names below are exactly as written in
Dart**; if the audit document referred to different names, the code is
authoritative.

### 5.1 `generate_recurring_workshops_for_week(p_week_start date)`

- **Called by:** [`DashboardRepository.generateWeeklyWorkshops`](../lib/features/dashboard/data/dashboard_repository.dart#L48) → wraps `_client.rpc('generate_recurring_workshops_for_week', params: {'p_week_start': dateStr})`.
- **Purpose:** materialises `scheduled_workshops` instances for the requested
  Monday-to-Sunday week from active `workshop_series` rows.
- **Behaviour assumed (NEEDS DB VERIFICATION):** idempotent; safe to call
  multiple times for the same week without producing duplicates. Per
  [`weeklyWorkshopGenerationProvider`](../lib/features/dashboard/providers/dashboard_providers.dart#L28), the call must
  not throw — errors are caught and returned as a snackbar string.
- **Security:** likely `SECURITY DEFINER` to bypass RLS during insertion.
  NEEDS DB VERIFICATION.

### 5.2 `generate_daily_notifications()`

- **Called by:** [`NotificationsRepository.generateDailyNotifications`](../lib/features/notifications/data/notifications_repository.dart#L134) → `_client.rpc('generate_daily_notifications')`.
- **Purpose:** inserts birthday notifications for all admin/trainer recipients
  whose `children.birth_date` matches the current date. The SQL skeleton is
  documented inline in the repository file as a reference.
- **Behaviour:** uses a `NOT EXISTS` guard to avoid duplicate inserts on the
  same day.
- **Security:** `SECURITY DEFINER` per the inline doc comment.

### 5.3 `count_weekly_present_attendance(p_from date, p_to date) RETURNS integer`

- **Called by:** [`ChildrenRepository.countWeeklyPresentAttendances`](../lib/features/children/data/children_repository.dart) (Phase 2).
- **Purpose:** count of `attendance.status = 'present'` rows in
  `workshop_details` for `workshop_date BETWEEN p_from AND p_to`.
- **Behaviour:** read-only, `STABLE`, no `SECURITY DEFINER`.

---

## 6. Realtime channels (subscribed by the app)

`appRealtimeProvider` ([core/providers/app_realtime_provider.dart](../lib/core/providers/app_realtime_provider.dart)) subscribes to **8** tables; a separate
`teamChatRealtimeProvider` adds a 9th.

| Channel | Table | Provider |
|---|---|---|
| `rt:attendance` | `attendance` | `appRealtimeProvider` |
| `rt:scheduled_workshops` | `scheduled_workshops` | `appRealtimeProvider` |
| `rt:workshop_series` | `workshop_series` | `appRealtimeProvider` |
| `rt:workshop_enrollments` | `workshop_enrollments` | `appRealtimeProvider` |
| `rt:children` | `children` | `appRealtimeProvider` |
| `rt:payment_cycles` | `payment_cycles` | `appRealtimeProvider` |
| `rt:notifications` | `notifications` | `appRealtimeProvider` |
| `rt:demo_workshops` | `demo_workshops` | `appRealtimeProvider` |
| `global_team_chat:messages` | `team_chat_messages` | `teamChatRealtimeProvider` |

**Tables not subscribed:** `profiles`, `payments` (legacy), `workshop_children`
(legacy), `lesson_materials`, `child_progress`.

**Supabase Realtime opt-in:** each subscribed table must be enabled under
**Supabase → Database → Replication → supabase_realtime** publication.
NEEDS DB VERIFICATION that all 9 tables above are in the publication.

---

## 7. Relationship audit (Phase 5 Part 2)

This section lists relationship-level findings inferred from code. Severities:
HIGH / MEDIUM / LOW. Each finding identifies the proof point and the proposed
DB-side fix.

### HIGH

| # | Finding | Evidence | Fix |
|---|---|---|---|
| H1 | `attendance(scheduled_workshop_id, child_id)` is assumed unique by the app | `WorkshopsRepository.markAttendance` and `markAllPresent` both use `onConflict: 'scheduled_workshop_id,child_id'` on upsert | Add (or confirm) `UNIQUE (scheduled_workshop_id, child_id)` on the `attendance` table. Without it, a double-mark can create two rows |
| H2 | `workshop_enrollments(child_id, series_id)` is assumed unique by the app | `DemoWorkshopsRepository.enrollChild` uses `onConflict: 'child_id,series_id'`; `EnrollmentRepository.enrollChildInWorkshopSeries` catches `PostgrestException` code `23505` and falls back to UPDATE | Add (or confirm) `UNIQUE (child_id, series_id)` on `workshop_enrollments` |
| H3 | `scheduled_workshops.recurring_series_id` can be set without a matching `workshop_series` row | `EnrollmentRepository._ensureSeriesExists` is required to back-fill missing rows. The Phase 3 fix in `WorkshopsRepository.update()` upserts the series when toggling on; older rows may still have dangling ids | Confirm `FOREIGN KEY (recurring_series_id) REFERENCES workshop_series(id)` exists. If not, add it `DEFERRABLE INITIALLY DEFERRED` and back-fill |
| H4 | `attendance.payment_cycle_id` can be `NULL` mid-cycle and gets set by a server-side trigger or RPC the Flutter code does not own | Multiple repository docstrings reference `payment_cycle_id IS NULL` filtering. Phase 3 added defensive code (`payment_status_card._buildGroups`) to render `payment_cycles` rows that have no linked attendance | Audit the trigger that sets this column. Document its exact logic in Supabase. Verify it's transactional with `payment_cycles` insertion |

### MEDIUM

| # | Finding | Evidence | Fix |
|---|---|---|---|
| M1 | `demo_workshops` has no `series_id` FK at creation time | [`DemoWorkshopFormPage._save`](../lib/features/demo_workshops/presentation/demo_workshop_form_page.dart#L120) writes `workshop_type`, `workshop_title`, `trainer_id` but not `series_id` | See section 2.9. Future column proposal documented; not in scope to add now |
| M2 | `children.birth_date` is nullable; birthday notification trigger silently skips children with `NULL` | `AppNotification.fromMap` and birthday detection rely on title prefix; the SQL in the repo's inline doc skips NULL `birth_date` via `EXTRACT(...)` returning NULL → false | Consider `NOT NULL` if your business rule requires it. Otherwise document as accepted nullable |
| M3 | `payment_cycles.payment_method` has two representations: structured column AND legacy notes parsing | `_resolveMethod` in [`payment_status_card.dart`](../lib/features/children/presentation/widgets/payment_status_card.dart) and [`active_cycle_section.dart`](../lib/features/children/presentation/widgets/active_cycle_section.dart) tries `paymentMethod` first, then `RegExp(r'\bOP\b').hasMatch(notes)` | One-time backfill: `UPDATE payment_cycles SET payment_method = 'op' WHERE payment_method IS NULL AND notes ~ '\\mOP\\M'` (similarly for POS). Then drop the legacy parsing in Dart |
| M4 | `notifications` has no expiry mechanism; day-specific items are filtered in Dart | See `docs/notification_lifecycle.md` for the proposed `expires_at` column and migration | Not in Phase 5 scope to implement |

### LOW

| # | Finding | Evidence | Fix |
|---|---|---|---|
| L1 | `workshop_series.trainer_id` is nullable while `scheduled_workshops.trainer_id` is `NOT NULL` (inferred) | `EnrollmentRepository.fetchActiveWorkshopSeries` comment says "Does NOT join profiles — avoids silent row exclusion when trainer_id is NULL" | Decide whether trainer assignment is required at series creation. If yes, change the column to `NOT NULL` and add server-side validation |
| L2 | `team_chat_messages` has no per-user "read" tracking on the server | [`_ChatLastReadAtNotifier`](../lib/features/team_chat/providers/team_chat_providers.dart) uses SharedPreferences | Add `team_chat_reads(user_id, last_read_at)` table OR a `profiles.team_chat_last_read_at` column to sync across devices |
| L3 | `profiles.role` accepts arbitrary strings | No CHECK constraint proven | Add `CHECK (role IN ('admin','trainer','pending'))` if you adopt the `'pending'` role from Phase 1 audit option B; otherwise `CHECK (role IN ('admin','trainer'))` |
| L4 | `attendance.status` accepts arbitrary strings | Schema doc states `present | absent | motivated` but no CHECK proven | Add `CHECK (status IN ('present','absent','motivated'))` |

---

## 8. SQL recommendations

> All SQL below is **review-only**. Nothing is executed by the app. Apply
> manually in Supabase after reviewing.

### 8.1 REQUIRED (apply before scaling)

#### R1 — Unique on `attendance(scheduled_workshop_id, child_id)`

- **Why:** the upsert path in `WorkshopsRepository.markAttendance` relies on
  this constraint to coalesce double-marks.
- **Affected query:** `markAttendance`, `markAllPresent` in [workshops_repository.dart](../lib/features/workshops/data/workshops_repository.dart).
- **Expected impact:** prevents duplicate attendance rows. Slight write
  speedup for upserts.
- **Risk:** LOW. If duplicates already exist, the constraint creation will
  fail until those are reconciled (manual cleanup query needed first).

```sql
-- Detect duplicates first (read-only)
SELECT scheduled_workshop_id, child_id, COUNT(*) AS n
FROM public.attendance
GROUP BY scheduled_workshop_id, child_id
HAVING COUNT(*) > 1;

-- After cleanup:
ALTER TABLE public.attendance
  ADD CONSTRAINT attendance_workshop_child_unique
  UNIQUE (scheduled_workshop_id, child_id);
```

#### R2 — Unique on `workshop_enrollments(child_id, series_id)`

- **Why:** the same upsert/onConflict pattern in `DemoWorkshopsRepository.enrollChild` depends on it.
- **Affected query:** `enrollChild`, `enrollChildInWorkshopSeries`.
- **Expected impact:** prevents duplicate enrollments. The Dart code already
  handles `23505` (unique violation); the constraint must actually exist.
- **Risk:** LOW.

```sql
-- Detect duplicates first
SELECT child_id, series_id, COUNT(*) AS n
FROM public.workshop_enrollments
GROUP BY child_id, series_id
HAVING COUNT(*) > 1;

-- After cleanup:
ALTER TABLE public.workshop_enrollments
  ADD CONSTRAINT workshop_enrollments_child_series_unique
  UNIQUE (child_id, series_id);
```

#### R3 — Index `attendance(child_id)` and `attendance(scheduled_workshop_id)`

- **Why:** every per-child or per-workshop attendance read filters by one of
  these columns. `attendance` is the hottest table in the system.
- **Affected queries:** `fetchChildCurrentStatusRows`,
  `getAttendanceHistoryFull`, `getAttendanceHistoryForTrainerFull`,
  `markAttendance` upsert, plus all realtime payload joins.
- **Expected impact:** order-of-magnitude faster reads as attendance grows.
- **Risk:** LOW. Index creation cost is one-time; storage cost negligible at
  realistic data sizes.

```sql
CREATE INDEX IF NOT EXISTS idx_attendance_child_id
  ON public.attendance (child_id);

CREATE INDEX IF NOT EXISTS idx_attendance_workshop_id
  ON public.attendance (scheduled_workshop_id);
```

(The unique constraint R1 already covers `(scheduled_workshop_id, child_id)`
prefix queries, so a standalone `child_id` index is the additional one
needed.)

#### R4 — Partial index `attendance(child_id) WHERE payment_cycle_id IS NULL`

- **Why:** [`ChildDetailsRepository.fetchChildCurrentStatusRows`](../lib/features/children/data/child_details_repository.dart#L48) filters
  `payment_cycle_id IS NULL` per child on every Status actual render.
- **Affected query:** Status actual card on the child details page.
- **Expected impact:** large speedup as historical attendance accumulates;
  the open cycle is always a tiny subset.
- **Risk:** LOW.

```sql
CREATE INDEX IF NOT EXISTS idx_attendance_child_open_cycle
  ON public.attendance (child_id)
  WHERE payment_cycle_id IS NULL AND is_archived = false;
```

#### R5 — Index `workshop_enrollments(series_id) WHERE is_active = true` and `workshop_enrollments(child_id) WHERE is_active = true`

- **Why:** the active-enrollment queries dominate every workshop details page
  and child details page open.
- **Affected queries:** `fetchActiveWorkshopSeries`,
  `fetchChildWorkshopSeries`, `fetchWorkshopSeriesChildren`,
  `fetchAvailableChildrenForSeries`, `getDetails`.
- **Expected impact:** large speedup, especially as inactive enrollments
  accumulate over time.
- **Risk:** LOW.

```sql
CREATE INDEX IF NOT EXISTS idx_workshop_enrollments_series_active
  ON public.workshop_enrollments (series_id)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_workshop_enrollments_child_active
  ON public.workshop_enrollments (child_id)
  WHERE is_active = true;
```

#### R6 — Index `scheduled_workshops(workshop_date)` and `scheduled_workshops(recurring_series_id)`

- **Why:** dashboard queries filter by `workshop_date` (today, week range);
  `recurring_series_id` is used by `WorkshopsRepository.updateSeries`,
  `EnrollmentRepository.deactivateSeries`, `_ensureSeriesExists`, and the
  generation RPC.
- **Affected queries:** `getTodayWorkshops`, `getAllScheduledWorkshops`,
  `updateSeries`, `deactivateSeries`, `fetchWorkshopsByTrainer`, the
  weekly-generation RPC.
- **Expected impact:** moderate speedup; queries are usually small but
  frequent.
- **Risk:** LOW.

```sql
CREATE INDEX IF NOT EXISTS idx_scheduled_workshops_date
  ON public.scheduled_workshops (workshop_date);

CREATE INDEX IF NOT EXISTS idx_scheduled_workshops_series
  ON public.scheduled_workshops (recurring_series_id);
```

#### R7 — Index `payment_cycles(child_id)` and `payment_cycles(status)`

- **Why:** every Status plată read filters by `child_id`. The Plăți restante
  page reads `status IN ('due','overdue')` across all children.
- **Affected queries:** `fetchPaymentCycles`, `getPaymentsDue`,
  `DashboardRepository.getStats`.
- **Expected impact:** large speedup as the table grows.
- **Risk:** LOW.

```sql
CREATE INDEX IF NOT EXISTS idx_payment_cycles_child
  ON public.payment_cycles (child_id);

CREATE INDEX IF NOT EXISTS idx_payment_cycles_status
  ON public.payment_cycles (status)
  WHERE status IN ('due','overdue');
```

#### R8 — Index `notifications(recipient_id, is_read)` and `notifications(recipient_id, created_at desc)`

- **Why:** the bell badge filters by `recipient_id, is_read=false`. The full
  list and the recent dropdown both filter by `recipient_id` and order by
  `created_at desc`.
- **Affected queries:** `fetchUnreadCount`, `fetchNotifications`,
  `fetchRecentNotifications`.
- **Expected impact:** notifications scale fast with user count × days; this
  index keeps the badge query cheap.
- **Risk:** LOW.

```sql
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
  ON public.notifications (recipient_id)
  WHERE is_read = false;

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created
  ON public.notifications (recipient_id, created_at DESC);
```

### 8.2 RECOMMENDED (apply soon, not blocking)

#### Re1 — Index `children(is_active)`

- **Why:** `fetchAvailableChildrenForSeries` and many dropdowns filter by
  `is_active = true`. Most children will be active, so a partial index over
  the small inactive set is also fine.
- **Affected queries:** `fetchAvailableChildrenForSeries`, `getAll`,
  `findExistingChild` (partial).
- **Expected impact:** moderate.
- **Risk:** LOW.

```sql
CREATE INDEX IF NOT EXISTS idx_children_active
  ON public.children (is_active);
```

#### Re2 — Index `profiles(role)`

- **Why:** `trainersForDropdownProvider` and `TrainersRepository.getAll`
  filter by `role IN ('trainer','admin')`.
- **Affected queries:** the trainer dropdown that opens whenever the workshop
  form mounts.
- **Expected impact:** small but the dropdown was flagged by the audit as a
  frequent re-fetch.
- **Risk:** LOW.

```sql
CREATE INDEX IF NOT EXISTS idx_profiles_role
  ON public.profiles (role);
```

#### Re3 — Index `team_chat_messages(is_deleted, created_at desc)`

- **Why:** `fetchMessages` filters `is_deleted = false` and orders by
  `created_at DESC LIMIT 100`.
- **Affected queries:** chat page open + every realtime invalidation.
- **Expected impact:** keeps chat snappy as the table grows.
- **Risk:** LOW.

```sql
CREATE INDEX IF NOT EXISTS idx_team_chat_active_created
  ON public.team_chat_messages (created_at DESC)
  WHERE is_deleted = false;
```

#### Re4 — Index `demo_workshops(demo_date, status)`

- **Why:** `getTodayDemos` filters by `demo_date = today AND status =
  'scheduled'`.
- **Expected impact:** moderate as demos accumulate.
- **Risk:** LOW.

```sql
CREATE INDEX IF NOT EXISTS idx_demo_workshops_date_status
  ON public.demo_workshops (demo_date, status);
```

#### Re5 — Index `workshop_series(trainer_id, is_active)`

- **Why:** `fetchTrainerSeries`, `TrainersRepository.getAll` count step, and
  several dropdowns filter by trainer + active.
- **Expected impact:** small but frequent.
- **Risk:** LOW.

```sql
CREATE INDEX IF NOT EXISTS idx_workshop_series_trainer_active
  ON public.workshop_series (trainer_id)
  WHERE is_active = true;
```

#### Re6 — CHECK constraints

```sql
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('admin','trainer'));

ALTER TABLE public.attendance
  ADD CONSTRAINT attendance_status_check
  CHECK (status IN ('present','absent','motivated'));

ALTER TABLE public.payment_cycles
  ADD CONSTRAINT payment_cycles_status_check
  CHECK (status IN ('paid','due','overdue','cancelled','paid_advance'));

ALTER TABLE public.demo_workshops
  ADD CONSTRAINT demo_workshops_status_check
  CHECK (status IN ('scheduled','completed','no_show','cancelled','converted'));
```

- **Why:** prevent typos and stray values from breaking client logic.
- **Risk:** MEDIUM. Existing rows must already conform; verify with a
  `SELECT DISTINCT status FROM ...` first.

### 8.3 OPTIONAL (apply if a specific pain point appears)

| # | Index / change | Rationale |
|---|---|---|
| O1 | `CREATE INDEX idx_attendance_marked_at ON public.attendance (marked_at DESC)` | If a future audit log report sorts by `marked_at` globally |
| O2 | `CREATE INDEX idx_payments_child_created ON public.payments (child_id, created_at DESC)` | Only if the legacy `payments` table stays in use longer than expected |
| O3 | `ALTER TABLE notifications ADD COLUMN expires_at timestamptz` | See `docs/notification_lifecycle.md` |
| O4 | `ALTER TABLE demo_workshops ADD COLUMN series_id uuid REFERENCES workshop_series(id)` | See section 2.9 |
| O5 | `ALTER TABLE team_chat_messages ADD COLUMN edited_at timestamptz` | If you decide to add message editing |

---

## 9. NEEDS DB VERIFICATION — checklist

Items in this file flagged with this marker, grouped for a single Supabase
admin pass:

1. **Columns** — verify exact column existence and nullability:
   - `profiles.created_at`, `profiles.updated_at`
   - `workshop_series.workshop_type`, `day_of_week`, `end_time`,
     `created_at`, `updated_at`
   - `workshop_enrollments.enrolled_by`, `enrolled_at`, `created_at`,
     `updated_at`
   - `payment_cycles.updated_at`
   - `team_chat_messages.updated_at`
   - `notifications.action_url`, `priority`
   - `scheduled_workshops.recurring_series_id` (exact column name and FK
     definition)
2. **Foreign keys** — verify presence and ON DELETE behavior:
   - `scheduled_workshops.recurring_series_id → workshop_series.id`
   - `attendance.payment_cycle_id → payment_cycles.id`
   - all `confirmed_by` / `enrolled_by` / `created_by` / `marked_by` →
     `profiles.id`
3. **Triggers** — verify existence and exact behavior:
   - The trigger or RPC that closes a `payment_cycles` row when a child
     reaches 4 presents and sets `attendance.payment_cycle_id` on the four
     rows. This logic is **not in Flutter code** and is load-bearing.
4. **RPCs** — verify exact function bodies and `SECURITY DEFINER` flags:
   - `generate_recurring_workshops_for_week(p_week_start date)`
   - `generate_daily_notifications()`
   - `count_weekly_present_attendance(p_from date, p_to date)`
5. **Views** — verify each view exists and matches the column set referenced
   in code (section 4):
   - `dashboard_stats`, `dashboard_workshops`, `workshop_details`,
     `child_latest_attendance`, `child_current_status`,
     `child_current_status_rows` (bypassed but possibly still present),
     `child_payment_status_rows`, `child_payment_cycles`,
     `child_activity_history`, `child_current_cycle_summary`,
     `child_current_cycle_activity`.
6. **Realtime publication** — confirm all 9 subscribed tables (section 6)
   are members of the `supabase_realtime` publication.
7. **Legacy tables** — confirm presence and row counts of `payments`,
   `workshop_children`, `lesson_materials`, `child_progress`.

---

## 10. Removed / replaced from the previous schema doc

The previous `docs/database_schema.md` is fully superseded by this document.
Items that changed:

| Old doc | New status |
|---|---|
| `workshop_children` table listed as active | **Replaced** by `workshop_enrollments`. Not used by code; flagged for removal |
| `payments` table listed as active | **Reclassified as LEGACY** — see section 2.8 |
| `workshop_series`, `workshop_enrollments`, `payment_cycles`, `demo_workshops`, `team_chat_messages` missing | **Now documented** in sections 2.4, 2.5, 2.7, 2.9, 2.10 |
| Views: only 3 listed | **10 views documented** in section 4 |
| RPCs: none listed | **3 RPCs documented** in section 5 |
| Realtime: not mentioned | **9 channels documented** in section 6 |
| Build rule "Do not use old tables" | Carried forward — still applies |

---

*End of database_schema.md*
