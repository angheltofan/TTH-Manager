abstract final class AppConstants {
  // ── Supabase ──────────────────────────────────────────────────────────────
  //
  // Production values are the compile-time defaults. Every regular
  // `flutter run` / `flutter build web` / `flutter build windows` keeps
  // the production connection exactly as before.
  //
  // For local test runs against a scratch project (TTH Bot etc.), pass:
  //   --dart-define=SUPABASE_URL=https://<ref>.supabase.co
  //   --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
  // The overrides are resolved at compile time (const), so they do not
  // slow the app down at runtime and never appear in the shipped
  // release build unless explicitly passed at that build.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wsvlktbexzgihvlhkgqw.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_IKRphVhddN7mBWkdAPh_6g_hHC29tWX',
  );

  // ── App ───────────────────────────────────────────────────────────────────
  static const String appName = 'TTH Manager';
}
