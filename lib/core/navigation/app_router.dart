import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/fridge/presentation/fridge_page.dart';
import '../../features/inventory/presentation/inventory_page.dart';
import '../../features/quests/presentation/quests_page.dart';
import 'root_shell.dart';

// Owner: Person 4. To add a tab: build your feature page, then append one
// StatefulShellBranch below (and one NavItem in nav_items.dart). Keep new
// branches at the end of the list so additions don't collide.
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
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
