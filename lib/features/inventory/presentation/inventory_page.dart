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
    const InventoryItem(
      name: 'milk',
      quantity: 1,
      measurement: ItemMeasurement.liquid,
    ),
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
    final added = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => const _AddInventoryItemDialog(),
    );
    if (added != null) {
      setState(() => _inventory.add(added));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${added.name} added to your inventory.')),
        );
      }
    }
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
                label: Text(
                  '${item.displayDescription}'
                  '${item.expirationDate == null ? '' : ' • expires ${item.expirationLabel}'}',
                ),
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

class _AddInventoryItemDialog extends StatefulWidget {
  const _AddInventoryItemDialog();

  @override
  State<_AddInventoryItemDialog> createState() =>
      _AddInventoryItemDialogState();
}

class _AddInventoryItemDialogState extends State<_AddInventoryItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _nameController = TextEditingController();
  final _expirationController = TextEditingController();
  ItemMeasurement _measurement = ItemMeasurement.count;
  DateTime? _expirationDate;

  @override
  void dispose() {
    _quantityController.dispose();
    _nameController.dispose();
    _expirationController.dispose();
    super.dispose();
  }

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 20),
      helpText: 'Select expiration date',
    );
    if (selected == null) return;
    setState(() {
      _expirationDate = selected;
      _expirationController.text = '${selected.day.toString().padLeft(2, '0')}/'
          '${selected.month.toString().padLeft(2, '0')}/${selected.year}';
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      InventoryItem(
        name: _nameController.text.trim().toLowerCase(),
        quantity: double.parse(_quantityController.text),
        measurement: _measurement,
        expirationDate: _expirationDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.add_home_outlined),
      title: const Text('Add to home inventory'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell us what you already have so we can help you avoid buying duplicates.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _quantityController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _measurement == ItemMeasurement.count
                      ? 'Number of items'
                      : _measurement == ItemMeasurement.weight
                          ? 'Weight in grams'
                          : 'Volume in millilitres',
                  hintText: _measurement == ItemMeasurement.count
                      ? 'e.g. 2'
                      : 'e.g. 500',
                  prefixIcon: const Icon(Icons.numbers),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final quantity = double.tryParse(value ?? '');
                  if (quantity == null || quantity <= 0) {
                    return 'Enter a number greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ItemMeasurement>(
                key: const Key('measurement-type-field'),
                initialValue: _measurement,
                decoration: const InputDecoration(
                  labelText: 'How is this item measured?',
                  prefixIcon: Icon(Icons.straighten),
                  border: OutlineInputBorder(),
                ),
                items: ItemMeasurement.values
                    .map(
                      (measurement) => DropdownMenuItem(
                        value: measurement,
                        child: Text(measurement.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _measurement = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  hintText: 'e.g. milk',
                  prefixIcon: Icon(Icons.local_grocery_store_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an item name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expirationController,
                readOnly: true,
                onTap: _pickExpirationDate,
                decoration: InputDecoration(
                  labelText: 'Expiration date',
                  hintText: 'Select a date',
                  helperText: 'Required so we can remind you to use it in time',
                  prefixIcon: const Icon(Icons.event_outlined),
                  suffixIcon: _expirationDate == null
                      ? const Icon(Icons.arrow_drop_down)
                      : IconButton(
                          tooltip: 'Clear expiration date',
                          onPressed: () => setState(() {
                            _expirationDate = null;
                            _expirationController.clear();
                          }),
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
                validator: (_) => _expirationDate == null
                    ? 'Select an expiration date'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.add),
          label: const Text('Add to inventory'),
        ),
      ],
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
