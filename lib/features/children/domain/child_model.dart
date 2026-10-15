/// Typed model for a single child record from the `children` table.
/// Used by the Child Details page.
class ChildModel {
  const ChildModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.birthDate,
    this.parentName,
    this.parentPhone,
    this.notes,
    this.isActive,
    this.paymentType = 'paid',
    this.currentLevel,
    this.levelProgress,
  });

  final String id;
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final String? parentName;
  final String? parentPhone;
  final String? notes;
  final bool? isActive;

  /// 'paid' (regular paying participant) or 'free' (sponsored / family
  /// friend / scholarship). Defaults to 'paid' for safety when the DB
  /// column is unexpectedly absent.
  final String paymentType;

  /// `children.current_level` — 'Explorer' / 'Builder' / 'Programmer'
  /// / 'Architect', or null when the child has not been placed yet.
  final String? currentLevel;

  /// `children.level_progress` — 0..100, or null when not placed.
  final int? levelProgress;

  bool get isFreeParticipant => paymentType == 'free';

  String get fullName => '$firstName $lastName';

  /// Calculates age in years from [birthDate]. Returns null if no birthDate.
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int years = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      years--;
    }
    return years;
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) => ChildModel(
    id: map['id'] as String,
    firstName: (map['first_name'] as String?) ?? '',
    lastName: (map['last_name'] as String?) ?? '',
    birthDate: map['birth_date'] != null
        ? DateTime.tryParse(map['birth_date'] as String)
        : null,
    parentName: map['parent_name'] as String?,
    parentPhone: map['parent_phone'] as String?,
    notes: map['notes'] as String?,
    isActive: map['is_active'] as bool?,
    paymentType: (map['payment_type'] as String?) ?? 'paid',
    currentLevel: map['current_level'] as String?,
    levelProgress: (map['level_progress'] as num?)?.toInt(),
  );
}
