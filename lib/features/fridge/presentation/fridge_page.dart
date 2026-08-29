import 'package:flutter/material.dart';

// Owner: Person 2 — Food Rescue & AI
// Build here: expiry tracking, AI/recipe recommendations, marking items
// consumed. Only edit files under lib/features/fridge.
class FridgePage extends StatelessWidget {
  const FridgePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rescue My Fridge')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🥕', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text(
                'Expiry tracking & AI recipes — under construction.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
