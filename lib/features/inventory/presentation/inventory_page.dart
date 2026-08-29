import 'package:flutter/material.dart';

// Owner: Person 1 — Inventory & Shopping
// Build here: inventory list, shopping-list input/OCR, duplicate-purchase
// warnings. Only edit files under lib/features/inventory.
class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pause Before Purchase')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🛒', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text(
                'Inventory & shopping list — under construction.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
