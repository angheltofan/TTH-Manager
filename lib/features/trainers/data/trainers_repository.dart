import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/weekday_utils.dart';
import '../../children/domain/assigned_workshop.dart';
import '../../workshops/domain/workshop_series.dart';
import '../domain/trainer_profile.dart';

class TrainersRepository {
  const TrainersRepository(this._client);

  final SupabaseClient _client;

  /// Returns all profiles with role 'admin' or 'trainer'.
  /// workshopsCount is the number of ACTIVE recurring [workshop_series] rows
  /// assigned to that person — not weekly scheduled_workshop instances.
  /// Sort order: admin first, then by first_name → last_name.
  Future<List<TrainerProfile>> getAll() async {
    // Step 1: all admin/trainer profiles
    final profileData = await _client
        .from('profiles')
        .select('id, first_name, last_name, role, created_at, updated_at')
        .inFilter('role', ['admin', 'trainer']);

    final profiles = (profileData as List).cast<Map<String, dynamic>>();
    if (profiles.isEmpty) return [];

    // Step 2: count active workshop_series per trainer
    final trainerIds = profiles.map((p) => p['id'] as String).toList();
    final seriesData = await _client
        .from('workshop_series')
        .select('trainer_id')
        .inFilter('trainer_id', trainerIds)
        .eq('is_active', true);

    final countByTrainer = <String, int>{};
    for (final row
        in (seriesData as List).cast<Map<String, dynamic>>()) {
      final tid = row['trainer_id'] as String?;
      if (tid != null) {
        countByTrainer[tid] = (countByTrainer[tid] ?? 0) + 1;
      }
    }

    // Step 3: build + sort
    return (profiles.map((p) {
      final id = p['id'] as String;
      return TrainerProfile(
        id: id,
        firstName: (p['first_name'] as String?) ?? '',
        lastName: (p['last_name'] as String?) ?? '',
        role: (p['role'] as String?) ?? 'trainer',
        workshopsCount: countByTrainer[id] ?? 0,
        createdAt: p['created_at'] != null
            ? DateTime.tryParse(p['created_at'] as String)
            : null,
        updatedAt: p['updated_at'] != null
            ? DateTime.tryParse(p['updated_at'] as String)
            : null,
      );
    }).toList()
      ..sort((a, b) {
        // admins always first
        if (a.role == 'admin' && b.role != 'admin') return -1;
        if (a.role != 'admin' && b.role == 'admin') return 1;
        final cmp = a.firstName.compareTo(b.firstName);
        if (cmp != 0) return cmp;
        return a.lastName.compareTo(b.lastName);
      }));
  }

  Future<TrainerProfile?> getById(String id) async {
    final data = await _client
        .from('profiles')
        .select('id, first_name, last_name, role, created_at, updated_at')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;

    // Count active workshop_series for this trainer
    final seriesData = await _client
        .from('workshop_series')
        .select('id')
        .eq('trainer_id', id)
        .eq('is_active', true);
    final count = (seriesData as List).length;

    return TrainerProfile(
      id: data['id'] as String,
      firstName: (data['first_name'] as String?) ?? '',
      lastName: (data['last_name'] as String?) ?? '',
      role: (data['role'] as String?) ?? 'trainer',
      workshopsCount: count,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'] as String)
          : null,
    );
  }

  /// Returns active [WorkshopSeries] assigned to [trainerId], sorted Mon→Sun
  /// then by start_time then title. This is the canonical source for a
  /// trainer's permanent recurring schedule.
  Future<List<WorkshopSeries>> fetchTrainerSeries(
      String trainerId) async {
    final data = await _client
        .from('workshop_series')
        .select(
          'id, title, workshop_type, day_of_week, start_time, end_time, '
          'trainer_id, notes, is_active',
        )
        .eq('trainer_id', trainerId)
        .eq('is_active', true);

    return ((data as List)
        .map((e) => WorkshopSeries.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => compareByWeekday(
            dayA: a.dayOfWeek,
            dayB: b.dayOfWeek,
            timeA: a.startTime,
            timeB: b.startTime,
            titleA: a.title,
            titleB: b.title,
          )));
  }

  /// Legacy: deduped scheduled_workshops collapsed by series, sorted Mon→Sun.
  /// Kept for backward compatibility; prefer [fetchTrainerSeries] for
  /// permanent assignments.
  Future<List<AssignedWorkshop>> fetchWorkshopsByTrainer(
      String trainerId) async {
    final data = await _client
        .from('scheduled_workshops')
        .select(
          'id, title, workshop_type, day_of_week, start_time, end_time, '
          'recurring_series_id, workshop_date, is_active, trainer_id, '
          'profiles!trainer_id(first_name, last_name)',
        )
        .eq('trainer_id', trainerId);

    final all = (data as List)
        .map((e) => AssignedWorkshop.fromMap(e as Map<String, dynamic>))
        .toList();

    return (AssignedWorkshop.deduplicateBySeries(all)
      ..sort((a, b) => compareByWeekday(
            dayA: a.dayOfWeek,
            dayB: b.dayOfWeek,
            timeA: a.startTime,
            timeB: b.startTime,
            titleA: a.title,
            titleB: b.title,
          )));
  }
}
