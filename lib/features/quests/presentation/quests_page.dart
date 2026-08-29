import 'package:flutter/material.dart';

// Owner: Person 3 — Gamification
// Build here: daily quests, EcoPoints, streaks, levels/tree progression.
// Only edit files under lib/features/quests.
class QuestsPage extends StatelessWidget {
  const QuestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EcoQuests & Rewards')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎯', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text(
                'Quests, streaks & levels — under construction.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
