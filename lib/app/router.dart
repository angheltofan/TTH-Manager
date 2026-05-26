import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_client_provider.dart';
import '../core/widgets/app_shell.dart';
import '../features/auth/domain/app_profile.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/children/presentation/child_details_page.dart';
import '../features/children/presentation/child_form_page.dart';
import '../features/children/presentation/children_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/parent/presentation/parent_about_page.dart';
import '../features/parent/presentation/parent_child_details_page.dart';
import '../features/parent/presentation/parent_profile_page.dart';
import '../features/parent/presentation/parent_shell.dart';
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
/// notifies GoRouter to re-evaluate its redirect guard. Also exposes a
/// public [refresh] hook so the [routerProvider] can re-trigger redirect
/// evaluation once the async [currentProfileProvider] resolves a role.
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

  /// Re-emit a change notification. Called by the [routerProvider] when the
  /// current profile role transitions, so the redirect guard can re-run.
  void refresh() => notifyListeners();

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

  // Re-evaluate the redirect guard when the profile role resolves or
  // changes (e.g. async fetch completes after login, account switch).
  // The auth-state stream already fires on sign-in/sign-out — this covers
  // the gap between "logged in" and "role known".
  ref.listen<AsyncValue<AppProfile?>>(currentProfileProvider, (prev, next) {
    final prevRole = prev?.valueOrNull?.role;
    final nextRole = next.valueOrNull?.role;
    if (prevRole != nextRole) authNotifier.refresh();
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final loggedIn = authNotifier.isLoggedIn;
      final path = state.matchedLocation;
      final isAuthRoute = path == '/login';

      if (!loggedIn) {
        return isAuthRoute ? null : '/login';
      }

      // Logged in. Role may still be loading — fall back to staff behavior
      // (the existing default) until the profile resolves; the listener
      // above will re-trigger this redirect once the role is known.
      final profile = ref.read(currentProfileProvider).valueOrNull;
      final isParent = profile?.isParent ?? false;
      final isParentRoute =
          path == '/parent' || path.startsWith('/parent/');

      if (isAuthRoute) {
        // Post-login destination depends on role.
        return isParent ? '/parent' : '/dashboard';
      }

      if (profile == null) {
        // Role unknown yet — allow current navigation; re-evaluated on load.
        return null;
      }

      if (isParent && !isParentRoute) {
        // Parent must never reach admin/trainer screens.
        return '/parent';
      }
      if (!isParent && isParentRoute) {
        // Staff (or unknown non-parent role) bounced off /parent.
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/parent',
        builder: (context, state) => const ParentShell(),
      ),
      GoRoute(
        path: '/parent/children/:id',
        builder: (context, state) => ParentChildDetailsPage(
          childId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/parent/notifications',
        // Reuses the same NotificationsPage as the staff route — its
        // queries are already scoped to the current `recipient_id` and
        // contain no admin-only mutations.
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/parent/profile',
        builder: (context, state) => const ParentProfilePage(),
      ),
      GoRoute(
        path: '/parent/about',
        builder: (context, state) => const ParentAboutPage(),
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
