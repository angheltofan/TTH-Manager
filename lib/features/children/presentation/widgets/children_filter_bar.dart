import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../providers/children_providers.dart';

class ChildrenFilterBar extends ConsumerWidget {
  const ChildrenFilterBar({
    super.key,
    required this.searchCtrl,
    required this.isWide,
    required this.isTrainer,
    required this.onClear,
  });

  final TextEditingController searchCtrl;
  final bool isWide;
  final bool isTrainer;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workshopOptions = ref.watch(childrenWorkshopOptionsProvider);
    final trainers = ref.watch(childrenTrainersProvider);
    final currentWorkshop = ref.watch(childrenWorkshopFilterProvider);
    final currentTrainer = ref.watch(childrenTrainerFilterProvider);
    final currentActive = ref.watch(childrenActiveFilterProvider);
    // The default for the status filter is 'active'; anything else counts
    // as a non-default state that the clear-filters button should reset.
    final hasFilters = ref.watch(childrenSearchProvider).isNotEmpty ||
        currentWorkshop != null ||
        currentTrainer != null ||
        currentActive != 'active';
    final showTrainerFilter = !isTrainer;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:
          BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
    );
    final dropDeco = InputDecoration(
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: theme.cardTheme.color,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
      ),
    );

    final searchW = SizedBox(
      width: isWide ? 220 : double.infinity,
      child: AppSearchField(
        hint: 'Caută copil...',
        controller: searchCtrl,
        onChanged: (v) {
          ref.read(childrenSearchProvider.notifier).state = v;
          ref.read(childrenPageProvider.notifier).state = 0;
        },
      ),
    );

    final workshopW = DropdownButtonFormField<String>(
      key: ValueKey('filter-workshop-$currentWorkshop'),
      initialValue: currentWorkshop,
      isExpanded: true,
      decoration: dropDeco.copyWith(hintText: 'Toate atelierele'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Toate atelierele')),
        ...workshopOptions.map(
            (e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
      ],
      onChanged: (v) {
        ref.read(childrenWorkshopFilterProvider.notifier).state = v;
        ref.read(childrenPageProvider.notifier).state = 0;
      },
    );

    final trainerW = DropdownButtonFormField<String>(
      key: ValueKey('filter-trainer-$currentTrainer'),
      initialValue: currentTrainer,
      isExpanded: true,
      decoration: dropDeco.copyWith(hintText: 'Toți trainerii'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Toți trainerii')),
        ...trainers.map(
            (t) => DropdownMenuItem(value: t.key, child: Text(t.value))),
      ],
      onChanged: (v) {
        ref.read(childrenTrainerFilterProvider.notifier).state = v;
        ref.read(childrenPageProvider.notifier).state = 0;
      },
    );

    // Status filter: Active / Inactive / All.
    // Default is 'active' (managed by childrenActiveFilterProvider).
    final activeW = DropdownButtonFormField<String?>(
      key: ValueKey('filter-active-$currentActive'),
      initialValue: currentActive,
      isExpanded: true,
      decoration: dropDeco.copyWith(hintText: 'Status'),
      items: const [
        DropdownMenuItem<String?>(value: 'active', child: Text('Activi')),
        DropdownMenuItem<String?>(value: 'inactive', child: Text('Inactivi')),
        DropdownMenuItem<String?>(value: null, child: Text('Toți')),
      ],
      onChanged: (v) {
        ref.read(childrenActiveFilterProvider.notifier).state = v;
        ref.read(childrenPageProvider.notifier).state = 0;
      },
    );

    final clearW = Tooltip(
      message: 'Șterge filtrele',
      child: InkWell(
        onTap: onClear,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.error.withValues(alpha: 0.2)),
          ),
          child: const Icon(Icons.close_rounded,
              size: 18, color: AppColors.error),
        ),
      ),
    );

    if (isWide) {
      return Row(children: [
        searchW,
        const SizedBox(width: 10),
        SizedBox(width: 140, child: activeW),
        const SizedBox(width: 10),
        SizedBox(width: 180, child: workshopW),
        if (showTrainerFilter) ...[
          const SizedBox(width: 10),
          SizedBox(width: 170, child: trainerW),
        ],
        if (hasFilters) ...[const SizedBox(width: 10), clearW],
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        searchW,
        const SizedBox(height: 10),
        if (showTrainerFilter)
          Row(children: [
            Expanded(child: activeW),
            const SizedBox(width: 10),
            Expanded(child: workshopW),
            const SizedBox(width: 10),
            Expanded(child: trainerW),
          ])
        else
          Row(children: [
            Expanded(child: activeW),
            const SizedBox(width: 10),
            Expanded(child: workshopW),
          ]),
        const SizedBox(height: 10),
        if (hasFilters) ...[const SizedBox(height: 10), clearW],
      ],
    );
  }
}
