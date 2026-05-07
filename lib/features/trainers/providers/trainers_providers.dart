import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../children/domain/assigned_workshop.dart';
import '../data/trainers_repository.dart';
import '../domain/trainer_profile.dart';

final trainersRepositoryProvider = Provider<TrainersRepository>((ref) {
  return TrainersRepository(ref.watch(supabaseClientProvider));
});

final trainersListProvider = FutureProvider<List<TrainerProfile>>((ref) {
  return ref.watch(trainersRepositoryProvider).getAll();
});

final trainerDetailProvider =
    FutureProvider.family<TrainerProfile?, String>((ref, id) {
  return ref.watch(trainersRepositoryProvider).getById(id);
});

final trainerWorkshopsProvider =
    FutureProvider.family<List<AssignedWorkshop>, String>((ref, trainerId) {
  return ref
      .watch(trainersRepositoryProvider)
      .fetchWorkshopsByTrainer(trainerId);
});
