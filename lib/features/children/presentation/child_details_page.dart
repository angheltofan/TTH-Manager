import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/responsive.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../workshops/providers/enrollment_providers.dart';
import '../providers/child_details_providers.dart';
import 'widgets/assigned_workshops_card.dart';
import 'widgets/child_info_card.dart';
import 'widgets/current_status_card.dart';
import 'widgets/payment_status_card.dart';

class ChildDetailsPage extends ConsumerStatefulWidget {
  const ChildDetailsPage({super.key, required this.childId});
  final String childId;

  @override
  ConsumerState<ChildDetailsPage> createState() => _ChildDetailsPageState();
}

class _ChildDetailsPageState extends ConsumerState<ChildDetailsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(childByIdProvider(widget.childId));
      ref.invalidate(childWorkshopSeriesProvider(widget.childId));
      ref.invalidate(childCurrentStatusProvider(widget.childId));
      ref.invalidate(childCurrentStatusRowsProvider(widget.childId));
      ref.invalidate(childPaymentCyclesNewProvider(widget.childId));
      ref.invalidate(childPaymentStatusRowsProvider(widget.childId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final childAsync = ref.watch(childByIdProvider(widget.childId));
    final workshopsAsync =
        ref.watch(childWorkshopSeriesProvider(widget.childId));
    final isAdmin =
        ref.watch(currentProfileProvider).valueOrNull?.isAdmin ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/children'),
        ),
        title: const Text('Detalii copil'),
      ),
      body: childAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: AppError(message: e.toString())),
        data: (child) {
          if (child == null) {
            return const Center(child: Text('Copilul nu a fost găsit.'));
          }
          return SingleChildScrollView(
            padding: context.mobilePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Date copil
                ChildInfoCard(
                  child: child,
                  isAdmin: isAdmin,
                  workshopType: workshopsAsync.valueOrNull?.isNotEmpty == true
                      ? workshopsAsync.valueOrNull!.first.workshopType
                      : null,
                ),
                SizedBox(height: context.sectionGap),

                // 2. Atelierul la care vine
                AssignedWorkshopsCard(childId: widget.childId),
                SizedBox(height: context.sectionGap),

                // 3. Status actual
                CurrentStatusCard(childId: widget.childId),
                SizedBox(height: context.sectionGap),

                // 4. Status plată
                PaymentStatusCard(childId: widget.childId),
              ],
            ),
          );
        },
      ),
    );
  }
}
