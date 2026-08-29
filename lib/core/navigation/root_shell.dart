import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'nav_items.dart';

/// Bottom-nav scaffold wrapping each feature's own Navigator stack.
/// Owner: Person 4 (Dashboard & Integration).
class RootShell extends StatelessWidget {
  const RootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: kNavItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
                tooltip: '',
              ),
            )
            .toList(),
      ),
    );
  }
}
