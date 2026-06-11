import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/dashboard_workshop.dart';
import 'dashboard_workshop_item.dart';

/// Wraps [DashboardWorkshopItem] with the bottom spacing expected by the
/// "Ateliere azi" section.  Using the shared item keeps typography, badges,
/// and status display identical between both dashboard workshop sections.
class TodayWorkshopCard extends StatelessWidget {
  const TodayWorkshopCard({
    super.key,
    required this.workshop,
    this.isOwn = false,
  });

  final DashboardWorkshop workshop;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DashboardWorkshopItem(
        workshop: workshop,
        isOwn: isOwn,
        onTap: () => context.go('/workshops/${workshop.id}'),
      ),
    );
  }
}

