class InventoryItem {
  const InventoryItem(
      {required this.name, required this.quantity, this.unit = ''});

  final String name;
  final double quantity;
  final String unit;

  String get displayQuantity {
    final value = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    return unit.isEmpty ? value : '$value $unit';
  }
}
