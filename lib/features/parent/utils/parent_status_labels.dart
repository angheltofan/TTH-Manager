import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// Shared status → user-facing label / colour mappers for the parent UI.
// Previously duplicated as private helpers inside parent_shell.dart and
// parent_child_details_page.dart.

/// Maps `payment_cycles.status` to a parent-facing Romanian label.
String parentPaymentLabel(String? status) {
  switch (status) {
    case 'paid':
      return 'Plătit';
    case 'paid_advance':
      return 'Avans achitat';
    case 'due':
    case 'overdue':
      return 'Plată restantă';
    case 'cancelled':
      return 'Anulat';
    case null:
    case '':
      return '—';
    default:
      return status;
  }
}

/// Optional accent colour for the payment-status pill. Returns `null`
/// when the row should use the default text colour.
Color? parentPaymentColor(String? status) {
  switch (status) {
    case 'due':
    case 'overdue':
      return AppColors.error;
    case 'paid':
    case 'paid_advance':
      return const Color(0xFF10B981);
    default:
      return null;
  }
}

/// Maps `attendance.status` to a parent-facing Romanian label.
String parentAttendanceLabel(String? status) {
  switch (status) {
    case 'present':
      return 'Prezent';
    case 'absent':
      return 'Absent';
    case 'motivated':
      return 'Motivat';
    default:
      return status ?? '—';
  }
}
