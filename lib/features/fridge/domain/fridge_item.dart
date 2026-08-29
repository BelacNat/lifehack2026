enum FridgeItemStatus { overdue, today, soon, fresh, noExpiry, consumed }

class FridgeItem {
  const FridgeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.expiresOn,
    this.isConsumed = false,
  });

  final String id;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final DateTime? expiresOn;
  final bool isConsumed;

  FridgeItemStatus statusAt(DateTime now) {
    if (isConsumed) return FridgeItemStatus.consumed;
    if (expiresOn == null) return FridgeItemStatus.noExpiry;

    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      expiresOn!.year,
      expiresOn!.month,
      expiresOn!.day,
    );
    final daysRemaining = expiry.difference(today).inDays;

    if (daysRemaining < 0) return FridgeItemStatus.overdue;
    if (daysRemaining == 0) return FridgeItemStatus.today;
    if (daysRemaining <= 3) return FridgeItemStatus.soon;
    return FridgeItemStatus.fresh;
  }

  int? daysRemainingAt(DateTime now) {
    if (expiresOn == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      expiresOn!.year,
      expiresOn!.month,
      expiresOn!.day,
    );
    return expiry.difference(today).inDays;
  }

  FridgeItem copyWith({bool? isConsumed, double? quantity}) {
    return FridgeItem(
      id: id,
      name: name,
      category: category,
      quantity: quantity ?? this.quantity,
      unit: unit,
      expiresOn: expiresOn,
      isConsumed: isConsumed ?? this.isConsumed,
    );
  }

  Map<String, Object?> toRecipeIngredient(DateTime now) {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'days_until_expiry': daysRemainingAt(now),
    };
  }

  factory FridgeItem.fromDatabase(Map<String, dynamic> row) {
    final rawQuantity = row['quantity'];
    final quantity = rawQuantity is num
        ? rawQuantity.toDouble()
        : double.tryParse(rawQuantity?.toString() ?? '') ?? 1;
    final rawExpiry = row['expiry_date']?.toString();

    return FridgeItem(
      id: row['id'].toString(),
      name: row['name'] as String? ?? 'Unnamed food',
      category: row['category'] as String? ?? 'other',
      quantity: quantity,
      unit: row['unit'] as String? ?? 'pcs',
      expiresOn: rawExpiry == null ? null : DateTime.parse(rawExpiry),
      isConsumed: row['consumed_at'] != null,
    );
  }

  Map<String, Object?> toDatabaseInsert() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'expiry_date': expiresOn == null ? null : _dateOnly(expiresOn!),
    };
  }

  static String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
