import 'package:flutter/material.dart';

import '../../fridge/data/fridge_items_controller.dart';
import '../data/inventory_repository.dart';
import '../data/inventory_ocr_service.dart';
import '../data/inventory_ocr_service_factory.dart';
import '../domain/inventory_item.dart';
import '../domain/inventory_ocr_parser.dart';
import '../domain/shopping_list_checker.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, this.repository, this.ocrService});

  final InventoryRepository? repository;
  final InventoryOcrService? ocrService;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _shoppingController = TextEditingController();
  final _checker = ShoppingListChecker();
  final _inventory = <InventoryItem>[];
  late final InventoryRepository _repository;
  late final InventoryOcrService _ocrService;
  final _ocrParser = const InventoryOcrParser();
  bool _loadingInventory = true;
  bool _scanningInventory = false;
  bool _showTextInput = false;
  String? _inventoryError;
  ShoppingListResult? _result;
  ShoppingSuggestion? _savingAvoidance;
  _SortOption _sortOption = _SortOption.nameAsc;

  List<InventoryItem> get _sortedInventory {
    final sorted = [..._inventory];
    sorted.sort((a, b) {
      switch (_sortOption.field) {
        case _SortField.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SortField.category:
          return a.category.label.compareTo(b.category.label);
        case _SortField.expiry:
          if (a.expirationDate == null && b.expirationDate == null) return 0;
          if (a.expirationDate == null) return 1;
          if (b.expirationDate == null) return -1;
          return a.expirationDate!.compareTo(b.expirationDate!);
      }
    });
    return _sortOption.ascending ? sorted : sorted.reversed.toList();
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseInventoryRepository();
    _ocrService = widget.ocrService ?? createInventoryOcrService();
    _loadInventory();
    // The Fridge page (or Dashboard) may change the same underlying data —
    // e.g. "I ate this" consumes an item — so re-fetch whenever that shared
    // signal fires, keeping this list, the Fridge, and the Dashboard's
    // glance counts consistent.
    FridgeItemsController.items.addListener(_loadInventory);
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
    FridgeItemsController.items.removeListener(_loadInventory);
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
        FridgeItemsController.refresh();
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

  Future<void> _scanInventory() async {
    if (!_ocrService.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR scanning is available on Android and iOS.'),
        ),
      );
      return;
    }
    final source = await showModalBottomSheet<InventoryImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text('Scan items'),
              subtitle: Text(
                'Recognize grocery objects, receipt text, labels, or lists.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, InventoryImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(context, InventoryImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _scanningInventory = true);
    try {
      final recognition = await _ocrService.recognize(source);
      if (!mounted || recognition == null) return;
      final detected = _ocrParser.mergeImageDetections(
        _ocrParser.parse(recognition.text),
        recognition.imageDetections,
      );
      if (detected.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('No grocery items were detected. Try a clearer photo.'),
          ),
        );
        return;
      }
      setState(() => _scanningInventory = false);
      final reviewed = await showDialog<List<InventoryItem>>(
        context: context,
        builder: (context) => _ReviewScannedItemsDialog(items: detected),
      );
      if (reviewed == null || reviewed.isEmpty || !mounted) return;
      await _saveScannedItems(reviewed);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t read that image. Try another photo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanningInventory = false);
    }
  }

  Future<void> _saveScannedItems(List<InventoryItem> items) async {
    final saved = <InventoryItem>[];
    for (final item in items) {
      try {
        saved.add(await _repository.addItem(item));
      } catch (_) {
        // Continue so one invalid OCR result does not discard the other items.
      }
    }
    if (!mounted) return;
    setState(() => _inventory.addAll(saved));
    FridgeItemsController.refresh();
    final failed = items.length - saved.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? '${saved.length} ${saved.length == 1 ? 'item' : 'items'} added to your inventory.'
              : '${saved.length} added; $failed couldn’t be saved.',
        ),
      ),
    );
  }

  Future<void> _deleteInventoryItem(InventoryItem item) async {
    final id = item.id;
    if (id == null) return;
    try {
      await _repository.deleteItem(id);
      if (!mounted) return;
      setState(() => _inventory.remove(item));
      FridgeItemsController.refresh();
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
            'Scan your groceries to quickly add what you have at home.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('primary-scan-button'),
            onPressed: _scanningInventory ? null : _scanInventory,
            icon: _scanningInventory
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner_outlined),
            label: Text(
              _scanningInventory ? 'Scanning groceries…' : 'Scan groceries',
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              key: const Key('show-text-input-button'),
              onPressed: () => setState(() {
                _showTextInput = !_showTextInput;
              }),
              icon: Icon(
                _showTextInput ? Icons.expand_less : Icons.edit_outlined,
              ),
              label: Text(
                _showTextInput ? 'Hide text input' : 'Enter as text',
              ),
            ),
          ),
          if (_showTextInput) ...[
            const SizedBox(height: 8),
            TextField(
              key: const Key('shopping-list-text-field'),
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
            OutlinedButton.icon(
              onPressed: _checkList,
              icon: const Icon(Icons.search),
              label: const Text('Check before I shop'),
            ),
          ],
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
              PopupMenuButton<_SortOption>(
                tooltip: 'Sort',
                icon: const Icon(Icons.filter_list),
                initialValue: _sortOption,
                onSelected: (option) => setState(() => _sortOption = option),
                itemBuilder: (context) => _SortOption.values
                    .map((option) => PopupMenuItem(
                          value: option,
                          child: Row(
                            children: [
                              if (option == _sortOption)
                                const Icon(Icons.check, size: 18)
                              else
                                const SizedBox(width: 18),
                              const SizedBox(width: 8),
                              Text(option.label),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              TextButton.icon(
                onPressed: _scanningInventory ? null : _addInventoryItem,
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
            Column(
              children: _sortedInventory
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InventoryItemCard(
                          item: item,
                          onDelete: () => _deleteInventoryItem(item),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _AddInventoryItemDialog extends StatefulWidget {
  const _AddInventoryItemDialog({this.initialItem});

  final InventoryItem? initialItem;

  @override
  State<_AddInventoryItemDialog> createState() =>
      _AddInventoryItemDialogState();
}

class _AddInventoryItemDialogState extends State<_AddInventoryItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late final TextEditingController _nameController;
  final _expirationController = TextEditingController();
  late ItemMeasurement _measurement;
  InventoryCategory? _category;
  DateTime? _expirationDate;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _quantityController = TextEditingController(
      text: item == null
          ? '1'
          : (item.quantity == item.quantity.roundToDouble()
              ? item.quantity.toInt().toString()
              : item.quantity.toString()),
    );
    _nameController = TextEditingController(text: item?.name ?? '');
    _measurement = item?.measurement ?? ItemMeasurement.count;
    _category = item?.category;
    _expirationDate = item?.expirationDate;
    if (_expirationDate != null) {
      final date = _expirationDate!;
      _expirationController.text = '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

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
      title: Text(widget.initialItem == null
          ? 'Add to home inventory'
          : 'Review scanned item'),
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
          label: Text(
              widget.initialItem == null ? 'Add to inventory' : 'Save changes'),
        ),
      ],
    );
  }
}

class _ReviewScannedItemsDialog extends StatefulWidget {
  const _ReviewScannedItemsDialog({required this.items});

  final List<InventoryItem> items;

  @override
  State<_ReviewScannedItemsDialog> createState() =>
      _ReviewScannedItemsDialogState();
}

class _ReviewScannedItemsDialogState extends State<_ReviewScannedItemsDialog> {
  late final List<InventoryItem> _items = List.of(widget.items);
  late final Set<int> _selected = Set.of(
    List<int>.generate(widget.items.length, (index) => index),
  );

  Future<void> _edit(int index) async {
    final edited = await showDialog<InventoryItem>(
      context: context,
      builder: (context) => _AddInventoryItemDialog(initialItem: _items[index]),
    );
    if (edited != null) setState(() => _items[index] = edited);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.document_scanner_outlined),
      title: Text('Review ${_items.length} detected items'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OCR can make mistakes. Deselect anything that is not an item, or edit its details before saving.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < _items.length; index++)
                CheckboxListTile(
                  key: Key('scanned-item-$index'),
                  value: _selected.contains(index),
                  onChanged: (selected) => setState(() {
                    if (selected ?? false) {
                      _selected.add(index);
                    } else {
                      _selected.remove(index);
                    }
                  }),
                  title: Text(_items[index].displayDescription),
                  subtitle: Text(
                    '${_items[index].category.label} • expires ${_items[index].expirationLabel}',
                  ),
                  secondary: IconButton(
                    tooltip: 'Edit ${_items[index].name}',
                    onPressed: () => _edit(index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
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
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    [
                      for (var index = 0; index < _items.length; index++)
                        if (_selected.contains(index)) _items[index],
                    ],
                  ),
          icon: const Icon(Icons.add_home_outlined),
          label: Text('Add selected (${_selected.length})'),
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

enum _SortField { name, category, expiry }

enum _SortOption {
  nameAsc('Name (A–Z)', _SortField.name, true),
  nameDesc('Name (Z–A)', _SortField.name, false),
  categoryAsc('Category (A–Z)', _SortField.category, true),
  categoryDesc('Category (Z–A)', _SortField.category, false),
  expiryAsc('Expiry (soonest first)', _SortField.expiry, true),
  expiryDesc('Expiry (latest first)', _SortField.expiry, false);

  const _SortOption(this.label, this.field, this.ascending);

  final String label;
  final _SortField field;
  final bool ascending;
}

class _InventoryItemCard extends StatelessWidget {
  const _InventoryItemCard({required this.item, required this.onDelete});

  final InventoryItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final subtitleParts = [
      '${item.displayQuantity} · ${item.category.label}',
      if (item.expirationDate != null) 'expires ${item.expirationLabel}',
    ];

    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_categoryIcon(item.category), color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitleParts.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _categoryIcon(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.produce:
        return Icons.eco_outlined;
      case InventoryCategory.meat:
      case InventoryCategory.seafood:
        return Icons.egg_alt_outlined;
      case InventoryCategory.dairy:
      case InventoryCategory.beverage:
        return Icons.local_drink_outlined;
      case InventoryCategory.bakery:
        return Icons.bakery_dining_outlined;
      case InventoryCategory.pantry:
        return Icons.rice_bowl_outlined;
      case InventoryCategory.condiment:
        return Icons.liquor_outlined;
      case InventoryCategory.frozen:
        return Icons.ac_unit_outlined;
      case InventoryCategory.other:
        return Icons.kitchen_outlined;
    }
  }
}
