import 'inventory_item.dart';
import 'inventory_ocr_detection.dart';

class InventoryOcrParser {
  const InventoryOcrParser();

  List<InventoryItem> parse(String text, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final seen = <String>{};
    final items = <InventoryItem>[];

    for (final rawLine in text.split(RegExp(r'[\n\r]+'))) {
      final line = rawLine.trim();
      if (_shouldIgnore(line)) continue;
      final item = _parseLine(line, now);
      final key = item.name.toLowerCase();
      if (item.name.length < 2 || !seen.add(key)) continue;
      items.add(item);
    }
    return items;
  }

  List<InventoryItem> mergeImageDetections(
    List<InventoryItem> textItems,
    Iterable<InventoryOcrDetection> detections, {
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final items = List<InventoryItem>.of(textItems);
    final existing = items.map((item) => item.name.toLowerCase()).toSet();
    for (final detection in detections) {
      final name = _inventoryNameForLabel(detection.name);
      if (name == null || !existing.add(name)) continue;
      final category = _categoryFor(name);
      items.add(
        InventoryItem(
          name: name,
          quantity: detection.quantity.isFinite && detection.quantity > 0
              ? detection.quantity
              : 1,
          category: category,
          expirationDate: now.add(Duration(days: _shelfLifeDays(category))),
        ),
      );
    }
    return items;
  }

  List<InventoryItem> mergeImageLabels(
    List<InventoryItem> textItems,
    Iterable<String> labels, {
    DateTime? today,
  }) =>
      mergeImageDetections(
        textItems,
        labels.map((label) => InventoryOcrDetection(name: label)),
        today: today,
      );

  String? _inventoryNameForLabel(String label) {
    final normalized = label.toLowerCase().trim();
    if (normalized.length < 2 || normalized.length > 60) return null;
    if (!RegExp(r"^[a-z][a-z '\-]*$").hasMatch(normalized)) return null;
    const genericLabels = {
      'food',
      'fruit',
      'vegetable',
      'produce',
      'ingredient',
      'drink',
      'beverage',
      'container',
      'packaging',
    };
    if (genericLabels.contains(normalized)) return null;
    return normalized;
  }

  InventoryItem _parseLine(String line, DateTime now) {
    var working = line
        .replaceAll(RegExp(r'\s+[$£€]\s*\d+[.,]\d{2}\s*$'), '')
        .replaceAll(RegExp(r'\s+\d+[.,]\d{2}\s*$'), '')
        .trim();

    var quantity = 1.0;
    var measurement = ItemMeasurement.count;
    final quantityMatch = RegExp(
      r'^\s*(\d+(?:[.,]\d+)?)\s*(kg|g|grams?|l|ml|lit(?:re|er)s?|x|pcs?|pieces?)?\s*(?:x|of)?\s*',
      caseSensitive: false,
    ).firstMatch(working);
    if (quantityMatch != null) {
      quantity =
          double.tryParse(quantityMatch.group(1)!.replaceAll(',', '.')) ?? 1;
      final unit = quantityMatch.group(2)?.toLowerCase();
      if (unit == 'kg') {
        quantity *= 1000;
        measurement = ItemMeasurement.weight;
      } else if (unit == 'g' || (unit?.startsWith('gram') ?? false)) {
        measurement = ItemMeasurement.weight;
      } else if (unit == 'l' || (unit?.startsWith('lit') ?? false)) {
        quantity *= 1000;
        measurement = ItemMeasurement.liquid;
      } else if (unit == 'ml') {
        measurement = ItemMeasurement.liquid;
      }
      working = working.substring(quantityMatch.end).trim();
    }

    working = working
        .replaceAll(RegExp(r'^[\-•*]+\s*'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    final category = _categoryFor(working);
    return InventoryItem(
      name: working.toLowerCase(),
      quantity: quantity,
      measurement: measurement,
      category: category,
      expirationDate: now.add(Duration(days: _shelfLifeDays(category))),
    );
  }

  bool _shouldIgnore(String line) {
    if (line.length < 2 || !RegExp(r'[A-Za-z]').hasMatch(line)) return true;
    return RegExp(
      r'^(total|subtotal|tax|gst|vat|change|cash|card|visa|mastercard|receipt|thank\s*you|date|time|amount|balance|qty|description)\b',
      caseSensitive: false,
    ).hasMatch(line);
  }

  InventoryCategory _categoryFor(String name) {
    final value = name.toLowerCase();
    if (RegExp(r'\b(milk|cheese|yogurt|butter|cream)\b').hasMatch(value)) {
      return InventoryCategory.dairy;
    }
    if (RegExp(
            r'\b(apples?|bananas?|oranges?|tomatoes?|potatoes?|onions?|lettuce|fruits?|vegetables?|spinach|carrots?)\b')
        .hasMatch(value)) {
      return InventoryCategory.produce;
    }
    if (RegExp(r'\b(chicken|beef|pork|bacon|ham|lamb|meat)\b')
        .hasMatch(value)) {
      return InventoryCategory.meat;
    }
    if (RegExp(r'\b(fish|salmon|tuna|prawn|shrimp|seafood)\b')
        .hasMatch(value)) {
      return InventoryCategory.seafood;
    }
    if (RegExp(r'\b(bread|bun|cake|pastry|bagel)\b').hasMatch(value)) {
      return InventoryCategory.bakery;
    }
    if (RegExp(r'\b(juice|water|coffee|tea|soda|drink)\b').hasMatch(value)) {
      return InventoryCategory.beverage;
    }
    if (RegExp(r'\b(sauce|ketchup|mustard|mayonnaise|dressing)\b')
        .hasMatch(value)) {
      return InventoryCategory.condiment;
    }
    if (RegExp(r'\b(frozen|ice cream)\b').hasMatch(value)) {
      return InventoryCategory.frozen;
    }
    if (RegExp(r'\b(rice|pasta|spaghetti|flour|sugar|cereal|beans|oil)\b')
        .hasMatch(value)) {
      return InventoryCategory.pantry;
    }
    return InventoryCategory.other;
  }

  int _shelfLifeDays(InventoryCategory category) => switch (category) {
        InventoryCategory.produce || InventoryCategory.bakery => 7,
        InventoryCategory.dairy ||
        InventoryCategory.meat ||
        InventoryCategory.seafood =>
          5,
        InventoryCategory.frozen => 90,
        InventoryCategory.pantry || InventoryCategory.condiment => 180,
        InventoryCategory.beverage => 30,
        InventoryCategory.other => 14,
      };
}
