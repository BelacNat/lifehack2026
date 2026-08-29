import 'package:flutter/material.dart';

import '../data/inventory_repository.dart';
import '../domain/inventory_item.dart';
import '../domain/shopping_list_checker.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, this.repository});

  final InventoryRepository? repository;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _shoppingController = TextEditingController();
  final _checker = ShoppingListChecker();
  final _inventory = <InventoryItem>[];
  late final InventoryRepository _repository;
  bool _loadingInventory = true;
  String? _inventoryError;
  ShoppingListResult? _result;
  ShoppingSuggestion? _savingAvoidance;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseInventoryRepository();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _loadingInventory = true;
      _inventoryError = null;
    });
    try {
      final items = await _repository.loadItems();
      if (!mounted) return;
      setState(() {
        _inventory
          ..clear()
          ..addAll(items);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inventoryError =
            'Couldn’t load your inventory. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _loadingInventory = false);
    }
  }

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
      try {
        final saved = await _repository.addItem(added);
        if (!mounted) return;
        setState(() => _inventory.add(saved));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${saved.name} added to your inventory.')),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t save this item. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _deleteInventoryItem(InventoryItem item) async {
    final id = item.id;
    if (id == null) return;
    try {
      await _repository.deleteItem(id);
      if (!mounted) return;
      setState(() => _inventory.remove(item));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} removed from your inventory.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t remove this item. Please try again.'),
        ),
      );
    }
  }

  Future<void> _skipDuplicate(ShoppingSuggestion suggestion) async {
    setState(() => _savingAvoidance = suggestion);
    try {
      await _repository.recordAvoidedPurchase(suggestion);
      if (!mounted) return;
      final current = _result!;
      final remainingItems = current.items
          .where((item) => !identical(item, suggestion.item))
          .toList();
      final remainingSuggestions = current.suggestions
          .where((item) => !identical(item, suggestion))
          .toList();
      setState(() {
        _result = ShoppingListResult(
          items: remainingItems,
          suggestions: remainingSuggestions,
        );
        _shoppingController.text =
            remainingItems.map((item) => item.displayDescription).join(', ');
        _shoppingController.selection = TextSelection.collapsed(
          offset: _shoppingController.text.length,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${suggestion.item.name} removed — purchase avoided!',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t record this choice. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingAvoidance = null);
    }
  }

  void _ignoreWarning(ShoppingSuggestion suggestion) {
    final current = _result;
    if (current == null) return;
    setState(() {
      _result = ShoppingListResult(
        items: current.items,
        suggestions: current.suggestions
            .where((item) => !identical(item, suggestion))
            .toList(),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Warning ignored — ${suggestion.item.name} stays on your list.',
        ),
      ),
    );
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
          if (_result != null) ...[
            const SizedBox(height: 12),
            _ResultCard(
              result: _result!,
              savingSuggestion: _savingAvoidance,
              onSkip: _skipDuplicate,
              onIgnore: _ignoreWarning,
            ),
          ],
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
          if (_loadingInventory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_inventoryError != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(_inventoryError!),
                trailing: IconButton(
                  tooltip: 'Retry',
                  onPressed: _loadInventory,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            )
          else if (_inventory.isEmpty)
            Text(
              'Nothing here yet. Add your first item!',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _inventory.map((item) {
                return InputChip(
                  avatar: const Icon(Icons.kitchen_outlined, size: 18),
                  label: Text(
                    '${item.displayDescription}'
                    '${item.expirationDate == null ? '' : ' • expires ${item.expirationLabel}'}',
                  ),
                  onDeleted: () => _deleteInventoryItem(item),
                );
              }).toList(),
            ),
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
  InventoryCategory? _category;
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
        category: _category!,
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
              DropdownButtonFormField<InventoryCategory>(
                key: const Key('category-field'),
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'Select a food category',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: InventoryCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _category = value),
                validator: (value) =>
                    value == null ? 'Select a category' : null,
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
  const _ResultCard({
    required this.result,
    required this.onSkip,
    required this.onIgnore,
    required this.savingSuggestion,
  });

  final ShoppingListResult result;
  final ValueChanged<ShoppingSuggestion> onSkip;
  final ValueChanged<ShoppingSuggestion> onIgnore;
  final ShoppingSuggestion? savingSuggestion;

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
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ${suggestion.message}'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: savingSuggestion == null
                                ? () => onSkip(suggestion)
                                : null,
                            icon: identical(savingSuggestion, suggestion)
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.remove_shopping_cart_outlined,
                                  ),
                            label: const Text('I’ll skip this'),
                          ),
                          TextButton(
                            onPressed: savingSuggestion == null
                                ? () => onIgnore(suggestion)
                                : null,
                            child: const Text('Ignore warning'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                result.items.isEmpty
                    ? 'Great choice — all duplicate purchases were removed.'
                    : 'We didn’t find any of these ${result.items.length} items in your home inventory.',
              ),
          ],
        ),
      ),
    );
  }
}
