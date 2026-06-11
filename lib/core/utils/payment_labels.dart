import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Canonical mapping from `payment_cycles.status` → user-facing Romanian
/// label, accent colour, and (optionally) the resolved payment method
/// suffix ("POS"/"OP"). Single source of truth for the parent portal and
/// any other surface that displays a payment cycle status.
///
/// Required label set (from the audit's Phase-2 spec):
///   • paid          → "Plată confirmată" (+ method)
///   • paid_advance  → "Achitat în avans" (+ method)
///   • due           → "Plată neconfirmată"
///   • overdue       → "Restant"
///   • cancelled     → "Anulat"
///   • null/unknown  → null display (caller hides the pill)
///
/// Method resolution: parent surfaces only have access to the
/// `payment_method` column ("pos"|"op"|null). The legacy fallback that
/// scanned `payment_cycles.notes` for "POS"/"OP" lives ONLY in the staff
/// `PaymentStatusCard` because staff queries can transport `notes`. When
/// `payment_method` is null on a parent row, the suffix is simply
/// omitted — the label stays correct, just without a method badge.
class PaymentLabel {
  const PaymentLabel({
    required this.text,
    required this.color,
  });

  /// Display string, e.g. "Plată confirmată POS".
  final String text;

  /// Accent colour for the pill (foreground + alpha-blended fill/border).
  final Color color;
}

/// Returns the canonical pill for [status] + [paymentMethod], or `null`
/// when the cycle has no status / has an unknown status (UI hides the
/// pill in that case).
PaymentLabel? resolvePaymentLabel({
  required String? status,
  String? paymentMethod,
}) {
  final method = _normalisePaymentMethod(paymentMethod);
  switch (status) {
    case 'paid':
      return PaymentLabel(
        text: method != null
            ? 'Plată confirmată $method'
            : 'Plată confirmată',
        color: AppColors.success,
      );
    case 'paid_advance':
      return PaymentLabel(
        text: method != null
            ? 'Achitat în avans $method'
            : 'Achitat în avans',
        color: AppColors.info,
      );
    case 'due':
      return const PaymentLabel(
        text: 'Plată neconfirmată',
        color: AppColors.warning,
      );
    case 'overdue':
      return const PaymentLabel(
        text: 'Restant',
        color: AppColors.error,
      );
    case 'cancelled':
      return const PaymentLabel(
        text: 'Anulat',
        color: AppColors.muted,
      );
    default:
      return null;
  }
}

/// Normalises a stored `payment_method` value to its display form
/// ("POS" / "OP"), or `null` when the column is empty.
String? _normalisePaymentMethod(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.toUpperCase();
}
