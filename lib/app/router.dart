import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_client_provider.dart';
import '../core/widgets/app_shell.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/children/presentation/child_details_page.dart';
import '../features/children/presentation/child_form_page.dart';
import '../features/children/presentation/children_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/payments_due/presentation/payments_due_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/trainers/presentation/trainer_details_page.dart';
import '../features/trainers/presentation/trainers_page.dart';
import '../features/workshops/presentation/workshop_details_page.dart';
import '../features/demo_workshops/presentation/demo_workshop_details_page.dart';
import '../features/demo_workshops/presentation/demo_workshop_form_page.dart';
import '../features/team_chat/presentation/team_chat_page.dart';
import '../features/workshops/presentation/workshop_form_page.dart';
import '../features/workshops/presentation/workshop_series_page.dart';

/// A [ChangeNotifier] that listens to Supabase auth-state changes and
/// notifies GoRouter to re-evaluate its redirect guard.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(SupabaseClient client) {
    _isLoggedIn = client.auth.currentSession != null;
    _subscription = client.auth.onAuthStateChange.listen((event) {
      final loggedIn = event.session != null;
      if (loggedIn != _isLoggedIn) {
        _isLoggedIn = loggedIn;
        notifyListeners();
      }
    });
  }

  late final StreamSubscription<AuthState> _subscription;
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final authNotifier = _AuthNotifier(client);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final loggedIn = authNotifier.isLoggedIn;
      final path = state.matchedLocation;
      final isAuthRoute = path == '/login';

      if (!loggedIn && !isAuthRoute) return '/login';
      if (loggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/payments-due',
            builder: (context, state) => const PaymentsDuePage(),
          ),
          GoRoute(
            path: '/workshops/new',
            builder: (context, state) => const WorkshopFormPage(),
          ),
          GoRoute(
            path: '/workshops/:id',
            builder: (context, state) => WorkshopDetailsPage(
              workshopId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/workshops/:id/edit',
            builder: (context, state) => WorkshopFormPage(
              workshopId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: '/workshop-series/:id',
            builder: (context, state) => WorkshopSeriesPage(
              seriesId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/children',
            builder: (context, state) => const ChildrenPage(),
          ),
          GoRoute(
            path: '/children/new',
            builder: (context, state) => const ChildFormPage(),
          ),
          GoRoute(
            path: '/children/:id',
            builder: (context, state) => ChildDetailsPage(
              childId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/children/:id/edit',
            builder: (context, state) => ChildFormPage(
              childId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: '/trainers',
            builder: (context, state) => const TrainersPage(),
          ),
          GoRoute(
            path: '/trainers/:id',
            builder: (context, state) => TrainerDetailsPage(
              trainerId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/demo-workshops/new',
            builder: (context, state) => const DemoWorkshopFormPage(),
          ),
          GoRoute(
            path: '/demo-workshops/:id',
            builder: (context, state) => DemoWorkshopDetailsPage(
              demoId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/team-chat',
            builder: (context, state) => const TeamChatPage(),
          ),
        ],
      ),
    ],
  );
});
