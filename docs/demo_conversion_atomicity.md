# Demo conversion atomicity — RPC design

**Status:** design only. Not implemented. Companion to
`docs/database_schema.md` section 2.9.

> The SQL below is a proposal. Do not apply without explicit approval and
> review. Until this RPC ships, the Flutter conversion flow remains as it
> is post-Phase-3.

---

## 1. The problem

The current "Înscrie definitiv" (convert demo to enrollment) action in
[`DemoWorkshopDetailsPage._convert`](../lib/features/demo_workshops/presentation/demo_workshop_details_page.dart#L67-L168)
runs **four sequential mutations** with no rollback:

| Step | Action | Repository call |
|---|---|---|
| 1 | Find existing child by `(first_name, last_name, parent_phone)` | `DemoWorkshopsRepository.findExistingChild` |
| 2 | Admin picks "link existing" or "create new" — modal dialog | (UI only) |
| 3a | If "create new": insert into `children` and capture id | `DemoWorkshopsRepository.createChild` |
| 3b | Pick a `series_id` (Phase 3 filters this dialog by demo's workshop_type) | (UI only) |
| 4 | Upsert into `workshop_enrollments (child_id, series_id, is_active=true, enrolled_by, enrolled_at)` | `DemoWorkshopsRepository.enrollChild` |
| 5 | Update `demo_workshops` row → `status='converted'`, `converted_child_id`, `converted_series_id` | `DemoWorkshopsRepository.markConverted` |

**Failure modes the current flow does not handle:**

| Failure | Outcome today |
|---|---|
| Step 3a succeeds, step 4 fails (e.g. RLS denies enrollment write) | Orphan `children` row with no enrollment. Next conversion attempt finds it via `findExistingChild` and may reuse it — but the original demo stays in `scheduled` |
| Step 4 succeeds, step 5 fails (network blip mid-call) | Enrollment exists but `demo_workshops.status` stays `scheduled`. UI shows the demo as still pending; a subsequent retry will try to enroll again. The `onConflict: 'child_id,series_id'` saves the duplicate-row case but the cycle of retries can hide the underlying issue |
| Any step fails after the user has dismissed the dialog | The admin sees a snackbar error but the partial state remains and is non-obvious to clean up |

The audit (Phase 3 Part 4) flagged this as the next refactor candidate
after the documentation phase.

---

## 2. Proposed RPC

Wrap the entire conversion in a single Postgres function executed inside
an implicit transaction. Either every write succeeds or none do.

### 2.1 Signature

```sql
-- DO NOT APPLY YET — proposal for review.
CREATE OR REPLACE FUNCTION public.convert_demo_to_enrollment(
  p_demo_id           uuid,
  p_existing_child_id uuid,        -- NULL when creating a new child
  p_first_name        text,        -- ignored if p_existing_child_id is set
  p_last_name         text,        -- ignored if p_existing_child_id is set
  p_parent_name       text,
  p_parent_phone      text,
  p_parent_email      text,
  p_series_id         uuid,
  p_enrolled_by       uuid         -- auth.uid() passed by the client
)
RETURNS TABLE (
  child_id      uuid,
  series_id     uuid,
  enrollment_id uuid
)
LANGUAGE plpgsql
SECURITY INVOKER  -- run as the caller, so RLS applies
SET search_path = public
AS $$
DECLARE
  v_child_id      uuid;
  v_enrollment_id uuid;
  v_demo_status   text;
BEGIN
  -- 1. Validate the demo exists and is in a convertible state.
  SELECT status INTO v_demo_status
  FROM demo_workshops
  WHERE id = p_demo_id
  FOR UPDATE;                       -- locks the demo row for the txn

  IF v_demo_status IS NULL THEN
    RAISE EXCEPTION 'Demo % not found', p_demo_id
      USING ERRCODE = 'no_data_found';
  END IF;

  IF v_demo_status = 'converted' THEN
    RAISE EXCEPTION 'Demo % already converted', p_demo_id
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- 2. Resolve / create the child row.
  IF p_existing_child_id IS NOT NULL THEN
    SELECT id INTO v_child_id
    FROM children
    WHERE id = p_existing_child_id;
    IF v_child_id IS NULL THEN
      RAISE EXCEPTION 'Child % not found', p_existing_child_id
        USING ERRCODE = 'no_data_found';
    END IF;
  ELSE
    INSERT INTO children (
      first_name, last_name, parent_name, parent_phone, parent_email,
      is_active
    )
    VALUES (
      p_first_name, p_last_name, p_parent_name, p_parent_phone,
      p_parent_email, true
    )
    RETURNING id INTO v_child_id;
  END IF;

  -- 3. Upsert the enrollment. Existing inactive row gets reactivated.
  INSERT INTO workshop_enrollments (
    child_id, series_id, is_active, enrolled_by, enrolled_at
  )
  VALUES (v_child_id, p_series_id, true, p_enrolled_by, now())
  ON CONFLICT (child_id, series_id)
  DO UPDATE SET
    is_active   = true,
    enrolled_by = EXCLUDED.enrolled_by,
    enrolled_at = EXCLUDED.enrolled_at
  RETURNING id INTO v_enrollment_id;

  -- 4. Flip the demo to converted with both linked ids.
  UPDATE demo_workshops
  SET
    status              = 'converted',
    converted_child_id  = v_child_id,
    converted_series_id = p_series_id,
    updated_at          = now()
  WHERE id = p_demo_id;

  RETURN QUERY SELECT v_child_id, p_series_id, v_enrollment_id;
END;
$$;
```

### 2.2 Why `SECURITY INVOKER` and not `SECURITY DEFINER`

Running the function as the caller means RLS still applies to each of the
internal statements. This is what we want for a demo conversion done by an
admin: the admin must legitimately have INSERT rights on `children` and
`workshop_enrollments`, and UPDATE rights on `demo_workshops`. Switching to
`SECURITY DEFINER` would silently bypass `docs/rls_policies.md`.

If your RLS turns out to forbid the trainer-role admin sub-case from
inserting into `children` directly, see section 4 for an alternative.

### 2.3 Atomicity guarantee

Every statement inside the function body runs in the **same transaction**
that PostgREST opens for the RPC call. A `RAISE EXCEPTION` aborts the
transaction; partial writes are rolled back. The Flutter client sees a
`PostgrestException` and shows an error snackbar exactly as today, but with
no orphaned `children` row.

The `SELECT ... FOR UPDATE` on `demo_workshops` at step 1 also prevents
double-conversion when an admin double-taps the button.

---

## 3. Input contract from Flutter

The client should resolve the "link vs new child" decision and the series
pick **before** calling the RPC, so the function receives a deterministic
input.

```dart
// Proposal — not implemented. Replacement for _convert() in
// demo_workshop_details_page.dart.
Future<void> _convertAtomic(DemoWorkshop demo) async {
  // 1. Same client-side "find existing" + "select series" dialogs as today.
  final existing = await repo.findExistingChild(...);
  final useExisting = (await _askLinkDialog(existing)) ?? false;
  final seriesId = await _pickSeries(demo);
  if (seriesId == null) return;

  // 2. One RPC call. No partial writes possible.
  final result = await _client.rpc('convert_demo_to_enrollment', params: {
    'p_demo_id':           demo.id,
    'p_existing_child_id': useExisting ? existing!['id'] : null,
    'p_first_name':        demo.childFirstName,
    'p_last_name':         demo.childLastName,
    'p_parent_name':       demo.parentName,
    'p_parent_phone':      demo.parentPhone,
    'p_parent_email':      demo.parentEmail,
    'p_series_id':         seriesId,
    'p_enrolled_by':       ref.read(currentUserProvider)?.id,
  }) as List;
  final row = result.first as Map<String, dynamic>;
  final childId = row['child_id'] as String;

  // 3. Invalidations stay the same as today.
  ref.invalidate(demoWorkshopByIdProvider(widget.demoId));
  ref.invalidate(todayDemoWorkshopsProvider);
  ref.invalidate(allChildrenProvider);
  ref.invalidate(activeWorkshopSeriesProvider);
  ref.invalidate(seriesEnrolledChildrenProvider(seriesId));
  ref.invalidate(availableChildrenForSeriesProvider(seriesId));
  ref.invalidate(childByIdProvider(childId));
  ref.invalidate(childWorkshopSeriesProvider(childId));
}
```

The four sequential repository calls (`findExistingChild`, `createChild`,
`enrollChild`, `markConverted`) collapse into one RPC. The first three of
those repository methods could be marked `@Deprecated` once the RPC ships,
and removed later.

---

## 4. RLS and security assumptions

| Concern | How it's handled |
|---|---|
| Admin-only conversion | The Flutter UI already gates `_AdminActionsCard` on `profile.isAdmin`. RLS on `demo_workshops` UPDATE should also restrict (see `docs/rls_policies.md` section 3.8). The RPC inherits both checks because it runs as `SECURITY INVOKER` |
| Child creation by admin | RLS on `children` INSERT must allow admin (see section 3.2). If admin policy is `WITH CHECK (public.is_admin())`, the RPC just works |
| Enrollment write | RLS on `workshop_enrollments` INSERT must allow admin (see section 3.4). Same logic |
| Trainer attempting conversion | UI does not surface the action. RLS on `demo_workshops` UPDATE blocks it server-side; the RPC will fail with `permission denied` |
| Double-conversion attempt | The `FOR UPDATE` lock + status check at step 1 makes the second attempt raise `invalid_parameter_value` |
| Mismatched series workshop_type | Not enforced in DB. The Flutter dialog already filters by workshop_type (Phase 3 Part 4) — keep that. Adding a hard check inside the RPC would require carrying the demo's `workshop_type` and comparing against `workshop_series.workshop_type`, which is straightforward to add if you want strict enforcement |

### Alternative: `SECURITY DEFINER` with explicit admin check

If your RLS turns out to be too restrictive for the function body to
succeed under the caller's identity, switch to `SECURITY DEFINER` and add
an explicit admin check at the top:

```sql
-- Alternative (do not apply yet)
SECURITY DEFINER
...
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admins can convert demos'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  ...
END;
```

The trade-off: `SECURITY DEFINER` bypasses every RLS check, so the admin
check must be the very first statement and must not be skippable. Prefer
`SECURITY INVOKER` if RLS allows it.

---

## 5. Returned values

`RETURNS TABLE (child_id uuid, series_id uuid, enrollment_id uuid)` — the
Flutter side gets all three ids back in one call:

- `child_id` — same value the client passed (when linking) or the newly
  generated UUID (when creating).
- `series_id` — echoed back for symmetry.
- `enrollment_id` — useful if the client wants to immediately invalidate a
  per-enrollment provider in the future.

If you prefer a single-row return, change to
`RETURNS jsonb AS $$ ... RETURN jsonb_build_object('child_id', v_child_id, ...); $$`
— either form is fine; the `TABLE` variant is more discoverable in the
Supabase dashboard.

---

## 6. Failure-mode test matrix (for the future implementation phase)

| Scenario | Expected behavior |
|---|---|
| Demo id does not exist | `no_data_found` raised; transaction aborted; UI shows snackbar |
| Demo already converted | `invalid_parameter_value` raised; transaction aborted |
| `p_existing_child_id` provided but row deleted between dialog and RPC | `no_data_found`; aborted |
| Enrollment unique conflict (child already enrolled) | `ON CONFLICT DO UPDATE` reactivates the row; conversion succeeds; demo flips to converted |
| Network error mid-call | Either the entire transaction committed (everything in place) or none of it. No partial state |
| Two admins click "Convert" simultaneously on different devices | The first transaction takes the `FOR UPDATE` lock and succeeds; the second sees `status='converted'` after the lock releases and raises `invalid_parameter_value`. UI on the second device shows the error |

---

## 7. Migration steps (for the future phase)

1. **Create the RPC** in Supabase (apply the SQL in section 2.1). Test it
   manually via the SQL editor with a known demo id.
2. **Add a Flutter method** `DemoWorkshopsRepository.convertDemoToEnrollment(...)`
   wrapping the `rpc('convert_demo_to_enrollment', ...)` call.
3. **Replace `_convert` in `demo_workshop_details_page.dart`** with the
   single-call version (sketch in section 3).
4. **Mark the old per-step methods** (`createChild`, `enrollChild`,
   `markConverted`) `@Deprecated`. Remove them in a follow-up once no
   callers remain.
5. **Verify** with the test matrix in section 6. Manual tests are enough for
   an internal tool; add automated tests if the project later adopts
   `flutter_test` coverage.
6. **Document** the new RPC in `docs/database_schema.md` section 5 (RPCs).

---

## 8. Open questions for review

1. **Hard-enforce workshop_type match inside the RPC?** Currently the
   Flutter dialog filters series by workshop_type but does not block a
   manual mismatch. If you want strict enforcement, add a
   `RAISE EXCEPTION` when `(SELECT workshop_type FROM workshop_series WHERE id = p_series_id) <> (SELECT workshop_type FROM demo_workshops WHERE id = p_demo_id)`.
2. **Return error codes vs messages.** The sketch uses generic
   `RAISE EXCEPTION ... USING ERRCODE = ...`. If the Flutter UI needs to
   present specific localized messages per failure, codify a custom error
   code namespace (e.g. `'TTH001'` for "already converted").
3. **Phase 6 candidate?** This RPC depends on the RLS policies in
   `docs/rls_policies.md`. Recommend ordering:
   a) Apply RLS policies → b) Apply schema/index recommendations from
   `docs/database_schema.md` → c) Implement this RPC.
4. **Audit trail.** If you want a permanent record of who converted what,
   consider adding a `demo_conversion_log` table written inside the RPC.
   Not in scope for the initial proposal.

---

*End of demo_conversion_atomicity.md*
