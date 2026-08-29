import 'package:flutter/material.dart';

class NavItem {
  const NavItem({required this.label, required this.icon, required this.path});

  final String label;
  final IconData icon;
  final String path;
}

// Bottom nav tabs. To add yours, append one entry — don't reorder or edit
// anyone else's line, so independent additions merge without conflict.
const List<NavItem> kNavItems = [
  NavItem(label: 'Home', icon: Icons.public, path: '/dashboard'),
  NavItem(label: 'Inventory', icon: Icons.shopping_cart, path: '/inventory'),
  NavItem(label: 'Fridge', icon: Icons.kitchen, path: '/fridge'),
  NavItem(label: 'Quests', icon: Icons.house, path: '/quests'),
];
