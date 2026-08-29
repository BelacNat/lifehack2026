import '../../../core/supabase/supabase_client.dart';
import '../domain/inventory_item.dart';
import '../domain/shopping_list_checker.dart';

abstract class InventoryRepository {
  Future<List<InventoryItem>> loadItems();
  Future<InventoryItem> addItem(InventoryItem item);
  Future<void> deleteItem(int id);
  Future<void> recordAvoidedPurchase(ShoppingSuggestion suggestion);
}

class SupabaseInventoryRepository implements InventoryRepository {
  static const _table = 'fridge_items';

  String get _userId {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('A signed-in user is required for inventory access.');
    }
    return userId;
  }

  @override
  Future<List<InventoryItem>> loadItems() async {
    final rows = await supabase
        .from(_table)
        .select('id, name, category, quantity, unit, expiry_date')
        .eq('user_id', _userId)
        .isFilter('consumed_at', null)
        .order('added_at');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<InventoryItem> addItem(InventoryItem item) async {
    final row = await supabase
        .from(_table)
        .insert({
          'name': item.name,
          'category': item.category.name,
          'quantity': item.quantity,
          'unit': _unitFor(item.measurement),
          'expiry_date': _dateOnly(item.expirationDate!),
          'user_id': _userId,
        })
        .select('id, name, category, quantity, unit, expiry_date')
        .single();
    return _fromRow(row);
  }

  @override
  Future<void> deleteItem(int id) async {
    await supabase.from(_table).delete().eq('id', id).eq('user_id', _userId);
  }

  @override
  Future<void> recordAvoidedPurchase(ShoppingSuggestion suggestion) async {
    await supabase.from('avoided_purchases').insert({
      'user_id': _userId,
      'inventory_item_id': suggestion.inventoryItem.id,
      'item_name': suggestion.item.name,
      'shopping_quantity': suggestion.item.quantity,
      'shopping_unit': _unitFor(suggestion.item.measurement),
    });
  }

  static InventoryItem _fromRow(Map<String, dynamic> row) {
    return InventoryItem(
      id: row['id'] as int,
      name: row['name'] as String,
      quantity: (row['quantity'] as num).toDouble(),
      measurement: _measurementFor(row['unit'] as String),
      category: InventoryCategory.values.byName(row['category'] as String),
      expirationDate: row['expiry_date'] == null
          ? null
          : DateTime.parse(row['expiry_date'] as String),
    );
  }

  static String _unitFor(ItemMeasurement measurement) {
    return switch (measurement) {
      ItemMeasurement.count => 'pcs',
      ItemMeasurement.weight => 'g',
      ItemMeasurement.liquid => 'ml',
    };
  }

  static ItemMeasurement _measurementFor(String unit) {
    return switch (unit.toLowerCase()) {
      'g' || 'kg' => ItemMeasurement.weight,
      'ml' || 'l' => ItemMeasurement.liquid,
      _ => ItemMeasurement.count,
    };
  }

  static String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
