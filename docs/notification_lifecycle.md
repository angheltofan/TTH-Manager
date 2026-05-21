# Notification lifecycle — design proposal

**Status:** design only. Not implemented. Companion to
`docs/database_schema.md` section 2.11 and section 8.3 (OPTIONAL O3).

> All SQL below is a proposal. Do not apply without explicit approval.
> Implementation should happen in a dedicated future phase.

---

## 1. Problem we are designing for

Some notifications are **temporary by nature**:

- Birthday notifications are only meaningful on the child's birthday (and
  optionally for a small grace window the day after).
- Future categories that will need the same treatment: "Workshop today",
  "Daily attendance reminder", potentially "Pending payment overdue today".

Today the only mechanism the app has to suppress yesterday's birthday rows
is a **client-side filter** in
[`notifications_repository.dart`](../lib/features/notifications/data/notifications_repository.dart) (Phase 3, Part 5). The filter
recognises only the birthday title prefix `'zi de na'` and is applied in
three places: full list, bell dropdown, unread count.

**Limitations of the current approach:**

| Limitation | Consequence |
|---|---|
| Only birthday is detected | Any new temporary type (e.g. "workshop today") must add itself to the Dart filter; the DB still serves stale rows to every other consumer |
| Client-side filter, server still returns the rows | Bandwidth wasted; PostgREST `limit(20)` for the bell can return 5 valid + 15 stale rows, leaving the user with a half-empty dropdown |
| Title-prefix detection is brittle | A typo or translation change in the trigger breaks the filter silently |
| No audit trail of "this row expired on date X" | Cannot rerun analytics retroactively to know which notifications were stale at a given time |

---

## 2. Proposal: `expires_at` + optional `event_date`

Add two columns to `public.notifications`:

```sql
-- DO NOT APPLY YET — proposal for review.
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS event_date date;
```

| Column | Purpose | Nullable | Set by |
|---|---|---|---|
| `expires_at` | Moment after which the notification is no longer shown in dropdown/badge. NULL = never expires | yes | Trigger / RPC at insert time |
| `event_date` | Logical date the notification refers to (the child's birthday, the workshop date). Useful for grouping and analytics | yes | Trigger / RPC at insert time |

### Why two columns instead of one

- `expires_at` is what the **client filter** uses. Simple `WHERE expires_at IS NULL OR expires_at > now()`.
- `event_date` is what **server-side cron / cleanup jobs** use. E.g. _"delete birthday rows where event_date < current_date - 30 days"_. It also lets the UI group rows ("Today", "Yesterday") without parsing `created_at` timezones.

Keeping the two separate avoids cramming both meanings into a single
column with conditional semantics.

### Setting them at generation time

Example for `generate_daily_notifications()` (birthday case):

```sql
-- Sketch (do not apply):
INSERT INTO notifications (
  title, body, type, recipient_id, related_child_id,
  event_date, expires_at
)
SELECT
  'Zi de naştere',
  c.first_name || ' ' || c.last_name || ' îşi serbează ziua astăzi!',
  'info',
  p.id,
  c.id,
  current_date,                                -- event_date
  date_trunc('day', current_date + 1)          -- expires_at = midnight next day
    AT TIME ZONE 'Europe/Bucharest'
FROM children c CROSS JOIN profiles p
WHERE c.is_active = true
  AND EXTRACT(MONTH FROM c.birth_date) = EXTRACT(MONTH FROM current_date)
  AND EXTRACT(DAY   FROM c.birth_date) = EXTRACT(DAY   FROM current_date)
  AND p.role IN ('admin', 'trainer')
  AND NOT EXISTS (
    SELECT 1 FROM notifications n
    WHERE n.recipient_id = p.id
      AND n.related_child_id = c.id
      AND n.event_date = current_date
  );
```

The `NOT EXISTS` guard now uses `event_date = current_date` instead of
parsing `created_at`, which is more robust.

For permanent notifications (payment overdue, new chat mention), simply
omit both columns — they default to NULL, meaning "never expires".

---

## 3. Filtering rules on the client

After the migration, the Dart filter becomes a simple `WHERE` clause.

### Full notifications page

Read everything **with history**, so admins can see expired entries when
needed. **Do not filter `expires_at` here.** The page shows the full audit
trail.

```dart
// Proposal — not implemented
final data = await _client
    .from('notifications')
    .select()
    .eq('recipient_id', userId)
    .order('created_at', ascending: false)
    .limit(100);
```

### Bell dropdown (recent)

Filter to: **unread OR created-today** AND **not expired**.

```dart
// Proposal — not implemented
final data = await _client
    .from('notifications')
    .select()
    .eq('recipient_id', userId)
    .or('is_read.eq.false,created_at.gte.$todayStr')
    .or('expires_at.is.null,expires_at.gt.${nowIso}')
    .order('created_at', ascending: false)
    .limit(20);
```

The current Dart-side birthday filter goes away.

### Unread count (badge)

Filter to: **unread** AND **not expired**.

```dart
// Proposal — not implemented
final data = await _client
    .from('notifications')
    .select('id', const FetchOptions(count: CountOption.exact, head: true))
    .eq('recipient_id', userId)
    .eq('is_read', false)
    .or('expires_at.is.null,expires_at.gt.${nowIso}');
return data.count ?? 0;
```

> Reminder: `FetchOptions(count: ..., head: true)` is **not supported** in
> `postgrest 2.7.0`. The actual implementation should either use an RPC
> (as Phase 2 did for `count_weekly_present_attendance`) or fetch
> lightweight columns and `.length` them as the current Phase 3 code does.

---

## 4. Server-side cleanup (optional)

`expires_at` only hides rows from the UI. Over time the table still grows.
A cron job (Supabase scheduled function or `pg_cron`) can prune:

```sql
-- Proposal: delete day-specific rows older than 30 days
DELETE FROM public.notifications
WHERE expires_at IS NOT NULL
  AND expires_at < now() - interval '30 days';
```

Keep permanent notifications forever (or until the user is deleted).

---

## 5. Migration steps (for the future phase)

1. **Add columns** (`ALTER TABLE notifications ADD COLUMN expires_at ..., event_date ...`).
2. **Add index** for the hot path:
   ```sql
   CREATE INDEX IF NOT EXISTS idx_notifications_unexpired
     ON public.notifications (recipient_id, is_read)
     WHERE expires_at IS NULL OR expires_at > now();
   -- NOTE: partial index condition with `now()` is not allowed in Postgres
   -- (immutable required). The practical alternative is a plain index on
   -- (recipient_id, expires_at) and let the planner combine it with R8 from
   -- database_schema.md.
   ```
   Realistic version:
   ```sql
   CREATE INDEX IF NOT EXISTS idx_notifications_expires
     ON public.notifications (expires_at);
   ```
3. **Backfill historic rows.** Existing birthday rows can be backfilled:
   ```sql
   UPDATE public.notifications
   SET event_date = (created_at AT TIME ZONE 'Europe/Bucharest')::date,
       expires_at = (date_trunc('day',
                       (created_at AT TIME ZONE 'Europe/Bucharest')) + interval '1 day')
                     AT TIME ZONE 'Europe/Bucharest'
   WHERE title ILIKE 'Zi de na%' AND expires_at IS NULL;
   ```
4. **Update `generate_daily_notifications()`** to populate the two columns
   on every insert (sketch in section 2).
5. **Switch Dart code** to filter on `expires_at` instead of title prefix.
   The Phase 3 helper `_isStaleDaySpecific(...)` becomes obsolete; remove
   it and its three call sites.
6. **Verify** with manual tests:
   - Insert a notification with `expires_at = now() - 1 minute`. Confirm it
     disappears from the badge and bell immediately on next fetch, remains
     on full list.
   - Re-run birthday RPC twice on the same day; confirm `NOT EXISTS` still
     blocks duplicates (using `event_date`, not `DATE(created_at)`).

---

## 6. Why this is not part of Phase 5

The user explicitly scoped Phase 5 to documentation. The Phase 3 client-side
filter is the bridge until this migration ships in a future phase. The
`TODO(notifications-expiry)` comment in
[`notifications_repository.dart`](../lib/features/notifications/data/notifications_repository.dart#L17-L23) points readers here.

---

## 7. Open questions for review

1. **Timezone for expiry.** The sketch uses `Europe/Bucharest`. Confirm the
   business operates exclusively in Romania, or generalise to per-user
   timezone (likely overkill for an internal tool).
2. **Should `event_date` be set on permanent notifications too?** E.g. for
   "payment due" the `event_date` could be the cycle's `period_end`. Useful
   for grouping but not strictly needed.
3. **Cleanup retention.** Default to 30 days for expired rows; tune later if
   the audit log grows past the operational need.
4. **Realtime impact.** New `expires_at` column triggers no extra realtime
   work; existing `rt:notifications` channel already broadcasts all
   INSERT/UPDATE/DELETE.
5. **RLS.** The proposed columns inherit existing `notifications` RLS (see
   `docs/rls_policies.md` section 3.9) — no policy change required.

---

*End of notification_lifecycle.md*
