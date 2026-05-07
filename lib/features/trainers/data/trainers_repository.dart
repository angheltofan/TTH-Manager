import 'package:supabase_flutter/supabase_flutter.dart';

import '../../children/domain/assigned_workshop.dart';
import '../domain/trainer_profile.dart';

class TrainersRepository {
  const TrainersRepository(this._client);

  final SupabaseClient _client;

  Future<List<TrainerProfile>> getAll() async {
    final data = await _client
        .from('profiles')
        .select('id, first_name, last_name, role, created_at, updated_at, scheduled_workshops!trainer_id(count)')
        .inFilter('role', ['admin', 'trainer'])
        .order('last_name');
    return (data as List)
        .map((e) => TrainerProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<TrainerProfile?> getById(String id) async {
    final data = await _client
        .from('profiles')
        .select('id, first_name, last_name, role, created_at, updated_at, scheduled_workshops!trainer_id(count)')
        .eq('id', id)
        .maybeSingle();
    return data != null ? TrainerProfile.fromMap(data) : null;
  }

  /// Returns one [AssignedWorkshop] per recurring series for this trainer.
  /// Weekly duplicate instances are collapsed via [AssignedWorkshop.deduplicateBySeries].
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

    return AssignedWorkshop.deduplicateBySeries(all);
  }
}
