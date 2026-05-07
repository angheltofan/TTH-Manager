import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/child_current_status.dart';
import '../domain/child_current_status_row.dart';
import '../domain/child_model.dart';
import '../domain/child_payment_cycle.dart';
import '../domain/child_payment_status_row.dart';

/// Data layer for the Child Details page.
/// Uses: children, attendance, scheduled_workshops, profiles,
///       child_current_status, child_current_status_rows,
///       child_payment_status_rows, payment_cycles.
class ChildDetailsRepository {
  const ChildDetailsRepository(this._client);

  final SupabaseClient _client;

  // ── Fetch a single child by ID ────────────────────────────────────────────

  Future<ChildModel?> fetchChildById(String childId) async {
    final data = await _client
        .from('children')
        .select(
            'id, first_name, last_name, birth_date, '
            'parent_phone, notes, is_active')
        .eq('id', childId)
        .maybeSingle();
    return data != null ? ChildModel.fromMap(data) : null;
  }

  // ── Current cycle summary from child_current_status view ──────────────────

  Future<ChildCurrentStatus?> fetchChildCurrentStatus(
      String childId) async {
    final data = await _client
        .from('child_current_status')
        .select()
        .eq('child_id', childId)
        .maybeSingle();
    return data != null ? ChildCurrentStatus.fromMap(data) : null;
  }

  // ── Current cycle rows directly from attendance table ────────────────────
  // Returns all rows where payment_cycle_id IS NULL and is_archived = false.
  // This bypasses the child_current_status_rows view which may apply a date
  // filter and miss older sessions still in the current open cycle.

  Future<List<ChildCurrentStatusRow>> fetchChildCurrentStatusRows(
      String childId) async {
    final data = await _client
        .from('attendance')
        .select(
            'id, child_id, status, observation, '
            'scheduled_workshops!scheduled_workshop_id('
            'title, workshop_date, day_of_week, start_time, end_time)')
        .eq('child_id', childId)
        .filter('payment_cycle_id', 'is', null)
        .eq('is_archived', false);

    final rows = (data as List).map((e) {
      final map = e as Map<String, dynamic>;
      final sw = map['scheduled_workshops'] as Map<String, dynamic>?;
      return ChildCurrentStatusRow(
        childId: (map['child_id'] as String?) ?? '',
        attendanceId: map['id'] as String?,
        workshopTitle: sw?['title'] as String?,
        workshopDate: sw?['workshop_date'] != null
            ? DateTime.tryParse(sw!['workshop_date'] as String)
            : null,
        dayOfWeek: sw?['day_of_week'] as String?,
        startTime: sw?['start_time'] as String?,
        endTime: sw?['end_time'] as String?,
        attendanceStatus: map['status'] as String?,
        observation: map['observation'] as String?,
      );
    }).toList();

    // Sort by workshop date asc, then start_time asc (client-side).
    rows.sort((a, b) {
      final dateCmp = (a.workshopDate ?? DateTime(0))
          .compareTo(b.workshopDate ?? DateTime(0));
      if (dateCmp != 0) return dateCmp;
      return (a.startTime ?? '').compareTo(b.startTime ?? '');
    });

    return rows;
  }

  // ── Payment history rows from child_payment_status_rows view ──────────────

  Future<List<ChildPaymentStatusRow>> fetchChildPaymentStatusRows(
      String childId) async {
    final data = await _client
        .from('child_payment_status_rows')
        .select()
        .eq('child_id', childId)
        .order('workshop_date', ascending: false);
    return (data as List)
        .map((r) =>
            ChildPaymentStatusRow.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // ── Payment cycles from payment_cycles table ──────────────────────────────

  Future<List<ChildPaymentCycle>> fetchPaymentCycles(
      String childId) async {
    final data = await _client
        .from('payment_cycles')
        .select()
        .eq('child_id', childId)
        .order('period_start', ascending: false);
    return (data as List)
        .map((r) =>
            ChildPaymentCycle.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // ── Confirm payment for a cycle ──────────────────────────────────────────

  Future<void> confirmPayment({
    required String cycleId,
    required String userId,
    String notes = '',
  }) async {
    await _client
        .from('payment_cycles')
        .update({
          'status': 'paid',
          'paid_at': DateTime.now().toUtc().toIso8601String(),
          'confirmed_by': userId,
          if (notes.isNotEmpty) 'notes': notes,
        })
        .eq('id', cycleId);
  }

  // ── Create advance payment cycle (direct INSERT, no row linking) ──────────
  // Does NOT set payment_cycle_id on attendance rows.
  // Rows stay in child_current_status_rows until the cycle closes at 4 presents.

  Future<void> markAdvancePayment({
    required String childId,
    required String currentUserId,
    String notes = '',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // Upsert: update existing paid_advance cycle instead of creating duplicates.
    final existing = await _client
        .from('payment_cycles')
        .select('id')
        .eq('child_id', childId)
        .eq('status', 'paid_advance')
        .maybeSingle();

    if (existing != null) {
      await _client.from('payment_cycles').update({
        'paid_at': now,
        'confirmed_by': currentUserId,
        if (notes.isNotEmpty) 'notes': notes,
      }).eq('id', existing['id'] as String);
    } else {
      await _client.from('payment_cycles').insert({
        'child_id': childId,
        'status': 'paid_advance',
        'paid_at': now,
        'confirmed_by': currentUserId,
        if (notes.isNotEmpty) 'notes': notes,
      });
    }
  }
}
