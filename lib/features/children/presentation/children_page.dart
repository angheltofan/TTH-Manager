import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/children_providers.dart';
import 'widgets/child_entry.dart';
import 'widgets/children_empty_state.dart';
import 'widgets/children_filter_bar.dart';
import 'widgets/children_info_row.dart';
import 'widgets/children_page_header.dart';
import 'widgets/children_pagination.dart';
import 'widgets/children_table_header.dart';

class ChildrenPage extends ConsumerStatefulWidget {
  const ChildrenPage({super.key});

  @override
  ConsumerState<ChildrenPage> createState() => _ChildrenPageState();
}

class _ChildrenPageState extends ConsumerState<ChildrenPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reset all filters every time this page opens so navigation back never
    // shows stale filter state. Done in a post-frame callback so Riverpod
    // notifications fire safely (element is fully mounted).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(childrenSearchProvider.notifier).state = '';
      ref.read(childrenActiveFilterProvider.notifier).state = null;
      ref.read(childrenWorkshopFilterProvider.notifier).state = null;
      ref.read(childrenTrainerFilterProvider.notifier).state = null;
      ref.read(childrenPageProvider.notifier).state = 0;
      _searchCtrl.clear();
    });
  }

  @override
  void dispose() {
    // Do NOT update providers here — notifying listeners during dispose causes
    // markNeedsBuild on a defunct ConsumerStatefulElement and throws an assert.
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    ref.read(childrenSearchProvider.notifier).state = '';
    ref.read(childrenActiveFilterProvider.notifier).state = null;
    ref.read(childrenWorkshopFilterProvider.notifier).state = null;
    ref.read(childrenTrainerFilterProvider.notifier).state = null;
    ref.read(childrenPageProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;
    final isTrainer = profile?.isTrainer ?? false;
    final filteredAsync = ref.watch(filteredChildrenProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ChildrenPageHeader(isAdmin: isAdmin),
                    const SizedBox(height: 16),
                    ChildrenFilterBar(
                      searchCtrl: _searchCtrl,
                      isWide: isWide,
                      isTrainer: isTrainer,
                      onClear: _clearFilters,
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
              filteredAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: SizedBox(height: 120, child: AppLoading()),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppError(message: e.toString()),
                  ),
                ),
                data: (children) {
                  if (children.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        child: ChildrenEmptyState(onClear: _clearFilters),
                      ),
                    );
                  }
                  final pageSize = ref.watch(childrenPageSizeProvider);
                  final totalPages =
                      ((children.length - 1) ~/ pageSize) + 1;
                  final page = ref
                      .watch(childrenPageProvider)
                      .clamp(0, totalPages - 1);
                  final paged = children
                      .skip(page * pageSize)
                      .take(pageSize)
                      .toList();
                  final rangeStart = page * pageSize + 1;
                  final rangeEnd =
                      (rangeStart + paged.length - 1).clamp(1, children.length);

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        ChildrenInfoRow(
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                          total: children.length,
                          pageSize: pageSize,
                          isWide: isWide,
                        ),
                        const SizedBox(height: 10),
                        if (isWide) ...[
                          const ChildrenTableHeader(),
                          Divider(
                            height: 1,
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.25),
                          ),
                        ],
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: paged.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.18),
                          ),
                          itemBuilder: (_, i) => ChildEntry(
                            child: paged[i],
                            isWide: isWide,
                            isAdmin: isAdmin,
                            isTrainer: isTrainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ChildrenPaginationRow(
                          page: page,
                          totalPages: totalPages,
                          onPageChanged: (p) => ref
                              .read(childrenPageProvider.notifier)
                              .state = p,
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
