import 'inventory_item.dart';

class ShoppingSuggestion {
  const ShoppingSuggestion({
    required this.item,
    required this.inventoryItem,
    required this.message,
    required this.covered,
    this.isPartialMatch = false,
  });
  final InventoryItem item;
  final InventoryItem inventoryItem;
  final String message;
  final bool covered;
  final bool isPartialMatch;
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
    'jug': 'jug',
    'jugs': 'jug',
    'can': 'can',
    'cans': 'can',
    'kg': 'kg',
    'g': 'g',
    'l': 'l',
    'ml': 'ml',
    'litre': 'l',
    'litres': 'l',
    'pack': 'pack',
    'packs': 'pack',
    'stick': 'stick',
    'sticks': 'stick',
    'tub': 'tub',
    'tubs': 'tub',
    'jar': 'jar',
    'jars': 'jar',
    'packet': 'packet',
    'packets': 'packet',
    'pouch': 'pouch',
    'pouches': 'pouch',
    'tray': 'tray',
    'trays': 'tray',
    'loaf': 'loaf',
    'loaves': 'loaf',
    'bunch': 'bunch',
    'bunches': 'bunch',
    'head': 'head',
    'heads': 'head',
    'clove': 'clove',
    'cloves': 'clove',
    'dozen': 'dozen',
  };

  static const _numberWords = <String, String>{
    'a': '1',
    'an': '1',
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
  };

  static const _descriptionWords = <String>{
    'carton',
    'cartons',
    'bag',
    'bags',
    'box',
    'boxes',
    'bottle',
    'bottles',
    'jug',
    'jugs',
    'can',
    'cans',
    'pack',
    'packs',
    'stick',
    'sticks',
    'tub',
    'tubs',
    'jar',
    'jars',
    'packet',
    'packets',
    'pouch',
    'pouches',
    'tray',
    'trays',
    'loaf',
    'loaves',
    'bunch',
    'bunches',
    'head',
    'heads',
    'clove',
    'cloves',
    'dozen',
  };

  ShoppingListResult check(String input, List<InventoryItem> inventory) {
    final parsed = _parse(input);
    final homeByName = <String, InventoryItem>{};
    for (final item in inventory) {
      final key = _normaliseName(item.name);
      final existing = homeByName[key];
      homeByName[key] = InventoryItem(
        id: existing?.id ?? item.id,
        name: item.name,
        quantity: (existing?.quantity ?? 0) + item.quantity,
        measurement: item.measurement,
        category: item.category,
        expirationDate: item.expirationDate,
      );
    }

    final suggestions = <ShoppingSuggestion>[];
    for (final wanted in parsed) {
      final wantedName = _normaliseName(wanted.name);
      var atHome = homeByName[wantedName];
      var isPartialMatch = false;
      if (atHome == null) {
        final partialMatches = homeByName.entries
            .where((entry) => _namesPartiallyMatch(wantedName, entry.key))
            .toList()
          ..sort((a, b) => _nameDistance(wantedName, a.key)
              .compareTo(_nameDistance(wantedName, b.key)));
        if (partialMatches.isNotEmpty) {
          atHome = partialMatches.first.value;
          isPartialMatch = true;
        }
      }
      if (atHome == null || atHome.quantity <= 0) continue;
      final compatibleUnits = wanted.measurement == atHome.measurement;
      final covered = compatibleUnits && atHome.quantity >= wanted.quantity;
      final homeAmount = atHome.displayDescription;
      suggestions.add(ShoppingSuggestion(
        item: wanted,
        inventoryItem: atHome,
        covered: covered,
        isPartialMatch: isPartialMatch,
        message: isPartialMatch
            ? 'Possible duplicate: you have $homeAmount in your inventory. Check it before buying ${wanted.name}.'
            : covered
                ? 'You already have $homeAmount. Use it first before buying more!'
                : compatibleUnits
                    ? 'You have $homeAmount. Check how much you really need before buying more.'
                    : 'You already have $homeAmount in your inventory. Check it before buying more!',
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
      var prepared = entry.toLowerCase().replaceFirst(
            RegExp(r'^(?:please\s+)?(?:buy|get|grab|need|want|pick\s+up)\s+'),
            '',
          );
      final firstWord = RegExp(r'^([a-z]+)\b').firstMatch(prepared)?.group(1);
      if (firstWord != null && _numberWords.containsKey(firstWord)) {
        prepared = prepared.replaceFirst(
          RegExp('^$firstWord\\b'),
          _numberWords[firstWord]!,
        );
      }
      final match = RegExp(
        r'^(?:(\d+(?:\.\d+)?)\s+)?(?:(cartons?|bags?|boxes?|bottles?|jugs?|cans?|packs?|sticks?|tubs?|jars?|packets?|pouches?|trays?|loaf|loaves|bunch(?:es)?|heads?|cloves?|dozen|kg|g|ml|l|litres?)\s+(?:of\s+)?)?(.+)$',
        caseSensitive: false,
      ).firstMatch(prepared);
      if (match == null) continue;
      final quantity = double.tryParse(match.group(1) ?? '') ?? 1;
      final unit = _units[(match.group(2) ?? '').toLowerCase()] ?? '';
      final measurement = unit == 'g' || unit == 'kg'
          ? ItemMeasurement.weight
          : unit == 'ml' || unit == 'l'
              ? ItemMeasurement.liquid
              : ItemMeasurement.count;
      final name = _displayName(match.group(3)!.trim());
      final key = '${_normaliseName(name)}|$measurement';
      final existing = combined[key];
      combined[key] = InventoryItem(
        name: existing?.name ?? name,
        quantity: (existing?.quantity ?? 0) + quantity,
        measurement: measurement,
      );
    }
    return combined.values.toList();
  }

  static String _displayName(String value) {
    final cleaned = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned == 'egg' ? 'eggs' : cleaned;
  }

  static String _normaliseName(String value) {
    var name = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    var words = name.split(' ');
    while (words.isNotEmpty &&
        (words.first == 'a' ||
            words.first == 'an' ||
            words.first == 'of' ||
            _descriptionWords.contains(words.first))) {
      words = words.sublist(1);
    }
    while (words.isNotEmpty && _descriptionWords.contains(words.last)) {
      words = words.sublist(0, words.length - 1);
    }
    name = words.join(' ');
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

  static bool _namesPartiallyMatch(String first, String second) {
    final firstWords =
        first.split(' ').where((word) => word.length >= 3).toSet();
    final secondWords =
        second.split(' ').where((word) => word.length >= 3).toSet();
    if (firstWords.isEmpty || secondWords.isEmpty) return false;
    return firstWords.containsAll(secondWords) ||
        secondWords.containsAll(firstWords);
  }

  static int _nameDistance(String first, String second) {
    final firstWords = first.split(' ').toSet();
    final secondWords = second.split(' ').toSet();
    return firstWords.difference(secondWords).length +
        secondWords.difference(firstWords).length;
  }
}
