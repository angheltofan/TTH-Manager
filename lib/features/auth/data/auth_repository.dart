import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_profile.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Signs the user up and immediately upserts a profile row.
  /// Works when Supabase email confirmation is disabled (internal apps).
  /// If the session is null (email confirmation required), the profile
  /// upsert is still attempted with the returned user id.
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final userId = response.user?.id;
    if (userId != null) {
      await _client.from('profiles').upsert({
        'id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'role': 'trainer',
      });
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AppProfile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return data != null ? AppProfile.fromMap(data) : null;
  }
}
