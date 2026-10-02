import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../children/providers/child_details_providers.dart';
import '../../../children/providers/children_providers.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../workshops/providers/enrollment_providers.dart';
import '../../domain/demo_workshop.dart';
import '../../providers/demo_workshops_providers.dart';

/// Shared "Înscrie definitiv" (convert demo → child + enrollment) flow,
/// reused by [DemoWorkshopDetailsPage] and the Demos list row so both
/// screens share the exact same user interaction and invalidation
/// surface.
///
/// Returns the new (or linked) child id on success, `null` on cancel.
///
/// Preconditions:
///   • Caller gates on `profile.isAdmin` — the UI must never surface
///     this flow for non-admins. RLS on `demo_workshops.update_admin`
///     also enforces admin-only at the DB level; if a trainer somehow
///     reaches this call, the RPC will error with
///     `insufficient_privilege` and the caller receives a snackbar.
///   • Guard against double invocation at the caller — a disabled
///     button during `_busy` is the canonical pattern.
Future<String?> runConvertDemoFlow({
  required BuildContext context,
  required WidgetRef ref,
  required DemoWorkshop demo,
}) async {
  final repo = ref.read(demoWorkshopsRepositoryProvider);

  // Step 1 — look for an existing active child by (first_name, last_name,
  // parent_phone). The repository scopes to is_active=true so an archived
  // match is not silently reused.
  final existing = await repo.findExistingChild(
    firstName: demo.childFirstName,
    lastName: demo.childLastName,
    phone: demo.parentPhone,
  );
  if (!context.mounted) return null;

  String? existingChildId;
  if (existing != null) {
    final link = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copil existent găsit'),
        content: Text(
          'Există deja un copil cu numele '
          '"${existing['first_name']} ${existing['last_name']}" și '
          'telefonul ${existing['parent_phone'] ?? '—'}.\n\n'
          'Vrei să legi demo-ul de acest copil existent?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Creează copil nou')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Folosește existent')),
        ],
      ),
    );
    if (!context.mounted) return null;
    if (link == true) {
      existingChildId = existing['id'] as String;
    }
  }

  // Step 2 — pick the workshop series. The dialog filters by the demo's
  // workshop_type so an admin doesn't accidentally enroll into an
  // unrelated series; if no match exists, the full list is shown.
  final seriesId = await showDialog<String>(
    context: context,
    builder: (ctx) => _SelectSeriesDialog(demoType: demo.workshopType),
  );
  if (seriesId == null || !context.mounted) return null;

  // Step 3 — single atomic RPC call. The RPC is idempotent: a second
  // call on an already-converted demo returns the existing linkage
  // with `enrollment_created = false`. FOR UPDATE prevents a race on
  // double-tap or two admins converting at the same time.
  try {
    final result = await repo.convertDemoToEnrollment(
      demoId: demo.id,
      seriesId: seriesId,
      existingChildId: existingChildId,
    );
    final childId = result.childId;

    // Local invalidations — realtime handles other tabs. Avoiding
    // family-wide invalidations where exact keys are known.
    ref.invalidate(demoWorkshopByIdProvider(demo.id));
    ref.invalidate(todayDemoWorkshopsProvider);
    ref.invalidate(demosForDayProvider);
    ref.invalidate(upcomingDemosProvider);
    ref.invalidate(historyDemosProvider);
    ref.invalidate(allChildrenProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(activeWorkshopSeriesProvider);
    ref.invalidate(seriesEnrolledChildrenProvider(seriesId));
    ref.invalidate(availableChildrenForSeriesProvider(seriesId));
    ref.invalidate(childWorkshopSeriesProvider(childId));
    ref.invalidate(childByIdProvider(childId));
    ref.invalidate(childCurrentStatusRowsProvider(childId));

    if (context.mounted) {
      final msg = result.enrollmentCreated
          ? 'Copilul a fost înscris cu succes.'
          : 'Demo-ul este deja convertit.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
    return childId;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Eroare: $e')));
    }
    return null;
  }
}

/// Workshop-series picker — filters by the demo's `workshop_type` and
/// falls back to the full list when nothing matches so the admin can
/// always complete the conversion.
class _SelectSeriesDialog extends ConsumerWidget {
  const _SelectSeriesDialog({required this.demoType});
  final String demoType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(activeWorkshopSeriesProvider);

    return AlertDialog(
      title: const Text('Selectează seria'),
      content: SizedBox(
        width: 340,
        child: seriesAsync.when(
          loading: () => const SizedBox(
              height: 80,
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => Text('Eroare: $e'),
          data: (seriesList) {
            if (seriesList.isEmpty) {
              return const Text(
                  'Nu există serii active disponibile.');
            }
            final demoTypeLower = demoType.trim().toLowerCase();
            final matching = demoTypeLower.isEmpty
                ? seriesList
                : seriesList
                    .where((s) =>
                        (s.workshopType ?? '').trim().toLowerCase() ==
                        demoTypeLower)
                    .toList();
            final visible = matching.isNotEmpty ? matching : seriesList;

            return ListView.separated(
              shrinkWrap: true,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = visible[i];
                return ListTile(
                  title: Text(s.title),
                  subtitle: s.dayOfWeek != null
                      ? Text(
                          '${s.dayOfWeek} · ${s.startTime.substring(0, 5)}')
                      : null,
                  onTap: () => Navigator.pop(context, s.id),
                  dense: true,
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează')),
      ],
    );
  }
}
