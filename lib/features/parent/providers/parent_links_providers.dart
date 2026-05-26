import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/parent_links_repository.dart';
import '../domain/parent_link.dart';

final parentLinksRepositoryProvider = Provider<ParentLinksRepository>((ref) {
  return ParentLinksRepository(ref.watch(supabaseClientProvider));
});

/// List of parents linked to a given child. AutoDispose so the cache is
/// dropped when the Child Details page unmounts.
final linkedParentsProvider = FutureProvider.family
    .autoDispose<List<ParentLink>, String>((ref, childId) {
  return ref.watch(parentLinksRepositoryProvider).getLinkedParents(childId);
});
