import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On Flutter Web, switch from the default hash-based URL strategy
  // (`#/foo`) to path-based (`/foo`) so the browser fragment isn't
  // consumed as a route. This is required for Supabase invite/recovery
  // links — their tokens arrive in the URL fragment (`#access_token=...`)
  // and would otherwise be misinterpreted as a Flutter route before the
  // Supabase SDK can parse them.
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: App()));
}