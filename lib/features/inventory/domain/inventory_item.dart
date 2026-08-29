enum ItemMeasurement {
  count('Count', ''),
  weight('Weight (grams)', 'g'),
  liquid('Liquid (millilitres)', 'ml');

  const ItemMeasurement(this.label, this.symbol);

  final String label;
  final String symbol;
}

class InventoryItem {
  const InventoryItem({
    this.id,
    required this.name,
    required this.quantity,
    this.measurement = ItemMeasurement.count,
    this.expirationDate,
  });

  final int? id;
  final String name;
  final double quantity;
  final ItemMeasurement measurement;
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
