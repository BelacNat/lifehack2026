import 'inventory_item.dart';

class ShoppingSuggestion {
  const ShoppingSuggestion(
      {required this.item, required this.message, required this.covered});
  final InventoryItem item;
  final String message;
  final bool covered;
}

class ShoppingListResult {
  const ShoppingListResult({required this.items, required this.suggestions});
  final List<InventoryItem> items;
  final List<ShoppingSuggestion> suggestions;
}

class ShoppingListChecker {
  static const _units = <String, String>{
    'carton': 'carton',
    'cartons': 'carton',
    'bag': 'bag',
    'bags': 'bag',
    'box': 'box',
    'boxes': 'box',
    'bottle': 'bottle',
    'bottles': 'bottle',
    'can': 'can',
    'cans': 'can',
    'kg': 'kg',
    'g': 'g',
    'l': 'l',
    'litre': 'l',
    'litres': 'l',
    'pack': 'pack',
    'packs': 'pack',
  };

  ShoppingListResult check(String input, List<InventoryItem> inventory) {
    final parsed = _parse(input);
    final homeByName = <String, InventoryItem>{};
    for (final item in inventory) {
      final key = _normaliseName(item.name);
      final existing = homeByName[key];
      homeByName[key] = InventoryItem(
        name: item.name,
        quantity: (existing?.quantity ?? 0) + item.quantity,
        unit: item.unit,
      );
    }

    final suggestions = <ShoppingSuggestion>[];
    for (final wanted in parsed) {
      final atHome = homeByName[_normaliseName(wanted.name)];
      if (atHome == null || atHome.quantity <= 0) continue;
      final compatibleUnits = wanted.unit.isEmpty ||
          atHome.unit.isEmpty ||
          wanted.unit == atHome.unit;
      if (!compatibleUnits) continue;
      final covered = atHome.quantity >= wanted.quantity;
      final homeAmount = '${atHome.displayQuantity} ${atHome.name}'.trim();
      suggestions.add(ShoppingSuggestion(
        item: wanted,
        covered: covered,
        message: covered
            ? 'You already have $homeAmount. Use it first before buying more!'
            : 'You have $homeAmount. Check how much you really need before buying more.',
      ));
    }
    return ShoppingListResult(items: parsed, suggestions: suggestions);
  }

  List<InventoryItem> _parse(String input) {
    final combined = <String, InventoryItem>{};
    final entries = input
        .split(RegExp(r'[,;\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    for (final entry in entries) {
      final match = RegExp(
        r'^(?:(\d+(?:\.\d+)?)\s+)?(?:(cartons?|bags?|boxes?|bottles?|cans?|packs?|kg|g|l|litres?)\s+(?:of\s+)?)?(.+)$',
        caseSensitive: false,
      ).firstMatch(entry);
      if (match == null) continue;
      final quantity = double.tryParse(match.group(1) ?? '') ?? 1;
      final unit = _units[(match.group(2) ?? '').toLowerCase()] ?? '';
      final name = _displayName(match.group(3)!.trim());
      final key = '${_normaliseName(name)}|$unit';
      final existing = combined[key];
      combined[key] = InventoryItem(
        name: existing?.name ?? name,
        quantity: (existing?.quantity ?? 0) + quantity,
        unit: unit,
      );
    }
    return combined.values.toList();
  }

  static String _displayName(String value) {
    final cleaned = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned == 'egg' ? 'eggs' : cleaned;
  }

  static String _normaliseName(String value) {
    var name = value.toLowerCase().trim();
    const aliases = {
      'eggs': 'egg',
      'milks': 'milk',
      'bacons': 'bacon',
      'spaghettis': 'spaghetti'
    };
    if (aliases.containsKey(name)) return aliases[name]!;
    if (name.endsWith('s') && name.length > 3) {
      name = name.substring(0, name.length - 1);
    }
    return name;
  }
}
