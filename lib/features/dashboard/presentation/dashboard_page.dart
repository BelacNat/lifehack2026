import 'package:flutter/material.dart';

// Owner: Person 4 — Dashboard & Integration
// Build here: home dashboard, impact statistics, user progress. Only edit
// files under lib/features/dashboard. Shared shell edits (app_router.dart,
// nav_items.dart, root_shell.dart) also route through you — keep those
// diffs append-only so other branches merge cleanly.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impact + Home')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🌍', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text(
                'Home dashboard & impact stats — under construction.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
