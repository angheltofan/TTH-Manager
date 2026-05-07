import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/auth_repository.dart';
import '../domain/app_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Fires an [AuthState] event every time authentication changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// The currently signed-in Supabase [User], or null.
/// Rebuilds whenever [authStateProvider] emits a new event.
final currentUserProvider = Provider<User?>((ref) {
  // Watch authStateProvider so this provider invalidates on every auth change.
  ref.watch(authStateProvider);
  return ref.read(supabaseClientProvider).auth.currentUser;
});

/// The full profile row from `public.profiles` for the current user.
/// Returns null when not authenticated.
/// Rebuilds (and re-fetches) whenever the current user changes.
final currentProfileProvider = FutureProvider<AppProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(authRepositoryProvider).getProfile(user.id);
});
