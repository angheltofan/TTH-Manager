import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/child_row.dart';

// ── Lightweight model used by the add/edit form ───────────────────────────────

class Child {
  const Child({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.birthDate,
    this.age,
    this.parentName,
    this.parentPhone,
    this.notes,
    this.isActive,
  });

  final String id;
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final int? age;
  final String? parentName;
  final String? parentPhone;
  final String? notes;
  final bool? isActive;

  factory Child.fromMap(Map<String, dynamic> m) => Child(
        id: m['id'] as String,
        firstName: m['first_name'] as String? ?? '',
        lastName: m['last_name'] as String? ?? '',
        birthDate: m['birth_date'] != null
            ? DateTime.tryParse(m['birth_date'] as String)
            : null,
        age: (m['age'] as num?)?.toInt(),
        parentName: m['parent_name'] as String?,
        parentPhone: m['parent_phone'] as String?,
        notes: m['notes'] as String?,
        isActive: m['is_active'] as bool?,
      );
}

class ChildrenRepository {
  const ChildrenRepository(this._client);

  final SupabaseClient _client;

  // ── List with embedded workshops + last attendance ────────────────────────

  Future<List<ChildRow>> getAllWithWorkshops() async {
    final childData = await _client
        .from('children')
        .select(
            '*, workshop_enrollments!child_id(is_active, workshop_series!series_id(id, title, workshop_type, day_of_week, start_time, end_time, trainer_id))')
        .order('last_name');

    // Query attendance table directly so we get marked_at for proper sorting.
    // Ordered by marked_at desc from DB; we then sort client-side by
    // (workshop_date desc, marked_at desc) and take the first per child.
    final attData = await _client
        .from('attendance')
        .select(
            'child_id, status, marked_at, scheduled_workshops!scheduled_workshop_id(workshop_date)');

    // Parse and sort: workshop_date desc, then marked_at desc.
    final attRows = (attData as List).expand<_AttRow>((row) {
      final childId = row['child_id'] as String?;
      if (childId == null) return const [];
      final wsData = row['scheduled_workshops'] as Map<String, dynamic>?;
      final workshopDateStr = wsData?['workshop_date'] as String?;
      if (workshopDateStr == null) return const [];
      final markedAtStr = row['marked_at'] as String?;
      return [
        _AttRow(
          childId: childId,
          status: (row['status'] as String?) ?? '',
          workshopDate: DateTime.parse(workshopDateStr),
          markedAt: markedAtStr != null
              ? DateTime.parse(markedAtStr)
              : DateTime(2000),
        ),
      ];
    }).toList()
      ..sort((a, b) {
        final d = b.workshopDate.compareTo(a.workshopDate);
        if (d != 0) return d;
        return b.markedAt.compareTo(a.markedAt);
      });

    final lastAttMap = <String, ({String status, DateTime date})>{};
    for (final att in attRows) {
      lastAttMap.putIfAbsent(
        att.childId,
        () => (status: att.status, date: att.workshopDate),
      );
    }

    return (childData as List).map((e) {
      final map = e as Map<String, dynamic>;
      final id = map['id'] as String;
      final att = lastAttMap[id];
      return ChildRow.fromMap(map,
          lastAttStatus: att?.status, lastAttDate: att?.date);
    }).toList();
  }

  // ── Single child row (for details page) ──────────────────────────────────

  Future<ChildRow?> getRowById(String id) async {
    final data = await _client
        .from('children')
        .select(
            '*, workshop_enrollments!child_id(is_active, workshop_series!series_id(id, title, workshop_type, day_of_week, start_time, end_time, trainer_id))')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;

    final attData = await _client
        .from('workshop_details')
        .select('child_id, attendance_status, workshop_date')
        .eq('child_id', id)
        .not('attendance_status', 'is', null)
        .order('workshop_date', ascending: false)
        .limit(1)
        .maybeSingle();

    return ChildRow.fromMap(
      data,
      lastAttStatus: attData?['attendance_status'] as String?,
      lastAttDate: attData != null
          ? DateTime.parse(attData['workshop_date'] as String)
          : null,
    );
  }

  // ── Simple CRUD ───────────────────────────────────────────────────────────

  Future<List<Child>> getAll() async {
    final data =
        await _client.from('children').select().order('last_name');
    return (data as List)
        .map((e) => Child.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Child?> getById(String id) async {
    final data = await _client
        .from('children')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data != null ? Child.fromMap(data) : null;
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _client.from('children').insert(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('children').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('children').delete().eq('id', id);
  }
}

// ── Private helper ────────────────────────────────────────────────────────────

class _AttRow {
  const _AttRow({
    required this.childId,
    required this.status,
    required this.workshopDate,
    required this.markedAt,
  });
  final String childId;
  final String status;
  final DateTime workshopDate;
  final DateTime markedAt;
}
