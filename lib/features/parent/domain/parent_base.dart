/// Lightweight basic fields for one of the parent's linked children.
/// Carries only the columns downstream providers actually consume —
/// `child_parents.relationship` is intentionally omitted (product rule:
/// the parent portal must never display or transport it).
class ParentChildBasic {
  const ParentChildBasic({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.isActive,
    this.isPrimary = false,
  });

  final String id;
  final String firstName;
  final String lastName;

  /// `children.is_active`. Inactive children are filtered out by the
  /// base provider, so consumers can treat this as always `true`. Kept
  /// on the model so a future refactor can opt into showing inactive
  /// children without changing the base query.
  final bool isActive;

  /// `child_parents.is_primary` — primary-first ordering.
  final bool isPrimary;

  String get fullName {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isEmpty && l.isEmpty) return '';
    if (l.isEmpty) return f;
    if (f.isEmpty) return l;
    return '$f $l';
  }
}

/// Single source of truth for the parent's linked children. Built by
/// `parentLinkedChildrenBaseProvider` from ONE `child_parents +
/// children` query, then consumed by every downstream parent provider
/// so none of them re-query the same table.
class ParentBase {
  const ParentBase({
    required this.basics,
    required this.childOrder,
    required this.childById,
  });

  /// Empty constant — used when the parent has no linked children or
  /// the auth user is not yet resolved.
  static const ParentBase empty = ParentBase(
    basics: [],
    childOrder: [],
    childById: {},
  );

  /// Active linked children, ordered primary-first then by
  /// `child_parents.created_at`.
  final List<ParentChildBasic> basics;

  /// Child IDs in primary-first order. Same order as [basics].
  final List<String> childOrder;

  /// O(1) lookup by child ID. Keys are exactly the values in
  /// [childOrder]; values are the matching entries from [basics].
  final Map<String, ParentChildBasic> childById;

  /// Convenience alias used by downstream providers that only need
  /// the ID list.
  List<String> get childIds => childOrder;

  bool get isEmpty => basics.isEmpty;
  bool get isNotEmpty => basics.isNotEmpty;
}

/// Single source of truth for the parent's active workshop enrollments.
/// Built by `parentEnrollmentsProvider` from ONE `workshop_enrollments`
/// query filtered by `child_id IN (base.childIds)`. Consumers
/// (`getNextWorkshopSummary`, `getWeeklyScheduleForBase`,
/// `buildSummaryForChild`) read this map instead of re-querying.
class ParentEnrollmentsBase {
  const ParentEnrollmentsBase({
    required this.seriesIds,
    required this.childrenBySeries,
    required this.seriesByChild,
  });

  static const ParentEnrollmentsBase empty = ParentEnrollmentsBase(
    seriesIds: [],
    childrenBySeries: {},
    seriesByChild: {},
  );

  /// Distinct active series IDs across every linked child.
  final List<String> seriesIds;

  /// `series_id → [childId…]` — used by the next-workshop summary and
  /// the weekly schedule to roll up child names per session.
  final Map<String, List<String>> childrenBySeries;

  /// `child_id → [seriesId…]` — used by `buildSummaryForChild` so the
  /// per-child summary does not re-query workshop_enrollments.
  final Map<String, List<String>> seriesByChild;

  bool get isEmpty => seriesIds.isEmpty;
  bool get isNotEmpty => seriesIds.isNotEmpty;
}
