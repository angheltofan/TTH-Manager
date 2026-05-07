import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/workshops_providers.dart';
import 'widgets/workshop_children_list.dart';
import 'widgets/workshop_header_card.dart';

// ─────────────────────────────────────────────────────────────────────────────

class WorkshopDetailsPage extends ConsumerStatefulWidget {
  const WorkshopDetailsPage({super.key, required this.workshopId});

  final String workshopId;

  @override
  ConsumerState<WorkshopDetailsPage> createState() =>
      _WorkshopDetailsPageState();
}

class _WorkshopDetailsPageState extends ConsumerState<WorkshopDetailsPage> {
  // Tracks which childIds are currently being saved
  final Set<String> _marking = {};

  Future<void> _mark(String childId, String status, String? observation) async {
    if (_marking.contains(childId)) return;
    setState(() => _marking.add(childId));
    try {
      final user = ref.read(currentUserProvider);
      await ref.read(workshopsRepositoryProvider).markAttendance(
            workshopId: widget.workshopId,
            childId: childId,
            status: status,
            observation: observation,
            markedBy: user?.id ?? '',
          );
      ref.invalidate(workshopDetailsProvider(widget.workshopId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _marking.remove(childId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync =
        ref.watch(workshopDetailsProvider(widget.workshopId));
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('Detalii atelier'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editează',
              onPressed: () =>
                  context.go('/workshops/${widget.workshopId}/edit'),
            ),
        ],
      ),
      body: detailsAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: AppError(message: e.toString())),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_outlined,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Nu există date pentru acest atelier.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.outline),
                  ),
                ],
              ),
            );
          }

          final first = rows.first;

          // Date restriction: can only mark on or after the workshop date
          final today = DateTime.now();
          final todayDate =
              DateTime(today.year, today.month, today.day);
          final workshopDay = DateTime(
            first.workshopDate.year,
            first.workshopDate.month,
            first.workshopDate.day,
          );
          final canMarkByDate = !todayDate.isBefore(workshopDay);

          // Role-based permission
          final hasRole = isAdmin ||
              (profile?.isTrainer == true &&
                  profile!.id == first.trainerId);
          final canMark = canMarkByDate && hasRole;
          final enrolled =
              rows.where((r) => r.childId != null).toList();

          return SingleChildScrollView(
            padding: context.mobilePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkshopHeaderCard(row: first),
                // Banner when workshop is in the future
                if (hasRole && !canMarkByDate) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_clock_outlined,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Prezența poate fi marcată începând cu ziua atelierului (${formatDate(first.workshopDate)}).',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                WorkshopChildrenList(
                  workshopId: widget.workshopId,
                  enrolled: enrolled,
                  marking: _marking,
                  canMark: canMark,
                  onMark: _mark,
                  onChildTap: (childId) =>
                      context.push('/children/$childId'),
                  isAdmin: isAdmin,
                  seriesId: first.seriesId,
                  onEnrolled: () => ref.invalidate(
                      workshopDetailsProvider(widget.workshopId)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

