import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../../core/widgets/status_pill.dart';
import '../../../../afterschool/domain/afterschool_program.dart';
import '../../../../afterschool/providers/afterschool_providers.dart';

/// Right-column panel for the Child Details "Afterschool" tab —
/// **attendance only**. Afterschool is NOT a paid product on the
/// child profile. Shows:
///   • header with program name + month navigator;
///   • attendance ratio `P / E prezențe` + breakdown line;
///   • `+ N planificate` + "În afara programului" badge when relevant.
///
/// No payment surface. No fee display. No "Marchează plătit". Workshop
/// payments remain in their own detail pane and are unaffected.
class AfterschoolChildDetailPane extends ConsumerStatefulWidget {
  const AfterschoolChildDetailPane({
    super.key,
    required this.childId,
    required this.childName,
    required this.program,
    required this.initialYear,
    required this.initialMonth,
    required this.onMonthChanged,
  });

  final String childId;
  final String childName;
  final AfterschoolProgram program;
  final int initialYear;
  final int initialMonth;
  final void Function(int year, int month) onMonthChanged;

  @override
  ConsumerState<AfterschoolChildDetailPane> createState() =>
      _AfterschoolChildDetailPaneState();
}

class _AfterschoolChildDetailPaneState
    extends ConsumerState<AfterschoolChildDetailPane> {
  late int _year = widget.initialYear;
  late int _month = widget.initialMonth;

  void _shiftMonth(int delta) {
    var y = _year;
    var m = _month + delta;
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    setState(() {
      _year = y;
      _month = m;
    });
    widget.onMonthChanged(y, m);
  }

  @override
  void didUpdateWidget(covariant AfterschoolChildDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.program.id != widget.program.id) {
      _year = widget.initialYear;
      _month = widget.initialMonth;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = AfterschoolChildMonthKey(
      childId: widget.childId,
      programId: widget.program.id,
      year: _year,
      month: _month,
    );
    final attendanceAsync =
        ref.watch(afterschoolMonthAttendanceProvider(key));
    final att = attendanceAsync.valueOrNull;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.program.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _MonthNavigator(
                year: _year,
                month: _month,
                onPrev: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Prezențe lunare',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (attendanceAsync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (att == null)
            Text(
              'Nu există date de prezență pentru această lună.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else
            _AttendanceBlock(att: att),
        ],
      ),
    );
  }
}

// ── Header month navigator ──────────────────────────────────────────

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });
  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = context.isMobile;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
            child: Text(
              _monthLabel(year, month, compact: compact),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _NavButton(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(icon, size: 18, color: AppColors.muted),
      ),
    );
  }
}

// ── Attendance block ────────────────────────────────────────────────

class _AttendanceBlock extends StatelessWidget {
  const _AttendanceBlock({required this.att});
  final dynamic att; // AfterschoolMonthAttendance

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final present = att.present as int;
    final expected = att.expected as int;
    final absent = att.absent as int;
    final unmarked = att.unmarked as int;
    final planned = att.plannedFuture as int;
    final unexpected = att.unexpected as int;

    final breakdown = [
      if (present > 0) '$present prezente',
      if (absent > 0) '$absent absente',
      if (unmarked > 0)
        unmarked == 1 ? '1 nemarcată' : '$unmarked nemarcate',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$present / $expected',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'prezențe',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          breakdown.isEmpty ? 'Nicio zi de urmărit încă.' : breakdown,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (planned > 0) ...[
          const SizedBox(height: 4),
          Text(
            '+ $planned ${planned == 1 ? "zi planificată" : "zile planificate"}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.info,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (unexpected > 0) ...[
          const SizedBox(height: 8),
          StatusPill(
            label: unexpected == 1
                ? '1 prezență în afara programului'
                : '$unexpected prezențe în afara programului',
            color: AppColors.warning,
          ),
        ],
        if (att.lastPresenceDate != null) ...[
          const SizedBox(height: 8),
          Text(
            'Ultima prezență: ${formatDate(att.lastPresenceDate as DateTime)}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

String _monthLabel(int year, int month, {bool compact = false}) {
  const long = [
    'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
    'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
  ];
  const short = [
    'ian', 'feb', 'mar', 'apr', 'mai', 'iun',
    'iul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];
  final name = compact ? short[month - 1] : long[month - 1];
  final capitalised = name[0].toUpperCase() + name.substring(1);
  return '$capitalised $year';
}
