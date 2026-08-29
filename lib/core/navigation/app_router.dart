import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/fridge/presentation/fridge_page.dart';
import '../../features/inventory/presentation/inventory_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/quests/presentation/quests_page.dart';
import '../supabase/supabase_client.dart';
import 'root_shell.dart';

// Owner: Person 4. To add a tab: build your feature page, then append one
// StatefulShellBranch below (and one NavItem in nav_items.dart). Keep new
// branches at the end of the list so additions don't collide.
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  redirect: (context, state) {
    final isSignedIn = supabase.auth.currentSession != null;
    final isGoingToSignIn = state.matchedLocation == '/sign-in';

    if (!isSignedIn && !isGoingToSignIn) return '/sign-in';
    if (isSignedIn && isGoingToSignIn) return '/dashboard';
    return null;
  },
  refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
  routes: [
    GoRoute(
      path: '/sign-in',
      builder: (context, state) => const SignInPage(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          RootShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/inventory',
              builder: (context, state) => const InventoryPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/fridge',
              builder: (context, state) => const FridgePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/quests',
              builder: (context, state) => const QuestsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Bridges a Stream (Supabase's auth state changes) into a Listenable so
/// go_router's redirect re-evaluates automatically on sign-in/sign-out,
/// instead of only on navigation.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}