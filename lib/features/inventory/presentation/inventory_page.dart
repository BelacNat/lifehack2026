import 'package:flutter/material.dart';

import '../domain/inventory_item.dart';
import '../domain/shopping_list_checker.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _shoppingController = TextEditingController();
  final _checker = ShoppingListChecker();
  final _inventory = <InventoryItem>[
    const InventoryItem(name: 'eggs', quantity: 6),
    const InventoryItem(name: 'milk', quantity: 1, unit: 'carton'),
  ];
  ShoppingListResult? _result;

  @override
  void dispose() {
    _shoppingController.dispose();
    super.dispose();
  }

  void _checkList() {
    if (_shoppingController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item to your list.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _result = _checker.check(_shoppingController.text, _inventory);
    });
  }

  Future<void> _addInventoryItem() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final added = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add what you have'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text);
              if (nameController.text.trim().isEmpty ||
                  quantity == null ||
                  quantity <= 0) {
                return;
              }
              Navigator.pop(
                context,
                InventoryItem(
                  name: nameController.text.trim().toLowerCase(),
                  quantity: quantity,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameController.dispose();
    quantityController.dispose();
    if (added != null) setState(() => _inventory.add(added));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pause Before Purchase')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Hello! What are we buying today?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Paste a list separated by commas or new lines. We’ll compare it with what’s already at home.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _shoppingController,
            minLines: 4,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Shopping list',
              alignLabelWithHint: true,
              hintText:
                  '12 eggs, 1 carton of milk,\n1 bag of bacon, 1 box of spaghetti',
              border: const OutlineInputBorder(),
              suffixIcon: _shoppingController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: () => setState(() {
                        _shoppingController.clear();
                        _result = null;
                      }),
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _checkList(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _checkList,
            icon: const Icon(Icons.search),
            label: const Text('Check before I shop'),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'At home',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: _addInventoryItem,
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _inventory.asMap().entries.map((entry) {
              final item = entry.value;
              return InputChip(
                avatar: const Icon(Icons.kitchen_outlined, size: 18),
                label: Text('${item.displayQuantity} ${item.name}'),
                onDeleted: () {
                  setState(() => _inventory.removeAt(entry.key));
                },
              );
            }).toList(),
          ),
          if (_result != null) ...[
            const SizedBox(height: 28),
            _ResultCard(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final ShoppingListResult result;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasWarnings = result.suggestions.isNotEmpty;
    return Card(
      color: hasWarnings ? colors.errorContainer : colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasWarnings
                      ? Icons.warning_amber_rounded
                      : Icons.eco_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasWarnings
                        ? 'WAIT! Check your kitchen first'
                        : 'Your list looks good!',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (hasWarnings)
              ...result.suggestions.map(
                (suggestion) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('• ${suggestion.message}'),
                ),
              )
            else
              Text(
                'We didn’t find any of these ${result.items.length} items in your home inventory.',
              ),
          ],
        ),
      ),
    );
  }
}
