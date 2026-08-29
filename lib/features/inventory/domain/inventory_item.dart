enum ItemMeasurement {
  count('Count', ''),
  weight('Weight (grams)', 'g'),
  liquid('Liquid (millilitres)', 'ml');

  const ItemMeasurement(this.label, this.symbol);

  final String label;
  final String symbol;
}

enum InventoryCategory {
  dairy('Dairy'),
  produce('Produce'),
  meat('Meat'),
  seafood('Seafood'),
  bakery('Bakery'),
  pantry('Pantry'),
  beverage('Beverage'),
  condiment('Condiment'),
  frozen('Frozen'),
  other('Other');

  const InventoryCategory(this.label);

  final String label;
}

class InventoryItem {
  const InventoryItem({
    this.id,
    required this.name,
    required this.quantity,
    this.measurement = ItemMeasurement.count,
    this.category = InventoryCategory.other,
    this.expirationDate,
  });

  final int? id;
  final String name;
  final double quantity;
  final ItemMeasurement measurement;
  final InventoryCategory category;
  final DateTime? expirationDate;

  String get displayQuantity {
    final value = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    if (measurement.symbol.isNotEmpty) return '$value ${measurement.symbol}';
    return value;
  }

  String get displayDescription => measurement == ItemMeasurement.count
      ? '$displayQuantity $name'
      : '$displayQuantity of $name';

  String get expirationLabel {
    final date = expirationDate;
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
