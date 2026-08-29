import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/fridge_item.dart';

abstract class FridgeRepository {
  Future<List<FridgeItem>> fetchItems();

  Future<FridgeItem> addItem(FridgeItem item);

  Future<void> setConsumed({
    required String id,
    required bool isConsumed,
  });
}

class SupabaseFridgeRepository implements FridgeRepository {
  const SupabaseFridgeRepository({SupabaseClient? client}) : _client = client;

  static const tableName = 'fridge_items';

  final SupabaseClient? _client;

  SupabaseClient get _database => _client ?? supabase;

  @override
  Future<List<FridgeItem>> fetchItems() async {
    final rows = await _database
        .from(tableName)
        .select()
        .order('expiry_date', ascending: true, nullsFirst: false)
        .order('id', ascending: true);

    return rows
        .map((row) => FridgeItem.fromDatabase(row))
        .toList(growable: false);
  }

  @override
  Future<FridgeItem> addItem(FridgeItem item) async {
    final row = await _database
        .from(tableName)
        .insert(item.toDatabaseInsert())
        .select()
        .single();

    return FridgeItem.fromDatabase(row);
  }

  @override
  Future<void> setConsumed({
    required String id,
    required bool isConsumed,
  }) async {
    await _database.from(tableName).update({
      'consumed_at':
          isConsumed ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', int.parse(id));
  }
}
