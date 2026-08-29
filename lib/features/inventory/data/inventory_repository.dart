import '../../../core/supabase/supabase_client.dart';
import '../domain/inventory_item.dart';

abstract class InventoryRepository {
  Future<List<InventoryItem>> loadItems();
  Future<InventoryItem> addItem(InventoryItem item);
  Future<void> deleteItem(int id);
}

class SupabaseInventoryRepository implements InventoryRepository {
  static const _table = 'inventory_items';

  Future<String> _userId() async {
    var user = supabase.auth.currentUser;
    if (user == null) {
      final response = await supabase.auth.signInAnonymously();
      user = response.user;
    }
    if (user == null) {
      throw StateError('Sign in is required to use your inventory.');
    }
    return user.id;
  }

  @override
  Future<List<InventoryItem>> loadItems() async {
    await _userId();
    final rows = await supabase
        .from(_table)
        .select('id, name, quantity, measurement, expiration_date')
        .order('created_at');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<InventoryItem> addItem(InventoryItem item) async {
    final userId = await _userId();
    final row = await supabase
        .from(_table)
        .insert({
          'user_id': userId,
          'name': item.name,
          'quantity': item.quantity,
          'measurement': item.measurement.name,
          'expiration_date': _dateOnly(item.expirationDate!),
        })
        .select('id, name, quantity, measurement, expiration_date')
        .single();
    return _fromRow(row);
  }

  @override
  Future<void> deleteItem(int id) async {
    await _userId();
    await supabase.from(_table).delete().eq('id', id);
  }

  static InventoryItem _fromRow(Map<String, dynamic> row) {
    return InventoryItem(
      id: row['id'] as int,
      name: row['name'] as String,
      quantity: (row['quantity'] as num).toDouble(),
      measurement: ItemMeasurement.values.byName(row['measurement'] as String),
      expirationDate: DateTime.parse(row['expiration_date'] as String),
    );
  }

  static String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
