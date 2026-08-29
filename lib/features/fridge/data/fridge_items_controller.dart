import 'package:flutter/foundation.dart';

import '../domain/fridge_item.dart';
import 'fridge_repository.dart';

/// Shared store for the signed-in user's fridge items, so other features
/// (currently the Dashboard's "Use these soon" shelf) show the same items
/// as the Fridge page, without duplicating the fetch. The Fridge page
/// publishes into [items] whenever it loads or refreshes; readers just
/// listen.
class FridgeItemsController {
  FridgeItemsController._();

  static final ValueNotifier<List<FridgeItem>> items =
      ValueNotifier<List<FridgeItem>>(const []);

  static Future<void>? _pending;

  /// Triggers a load the first time it's called (e.g. from the Dashboard,
  /// in case the user hasn't visited the Fridge tab yet this session).
  /// Safe to call repeatedly.
  static Future<void> ensureLoaded({FridgeRepository? fridgeRepository}) {
    if (items.value.isNotEmpty) return Future.value();
    return refresh(fridgeRepository: fridgeRepository);
  }

  /// Re-fetches regardless of current content — for pull-to-refresh or a
  /// manual retry after a failed load.
  static Future<void> refresh({FridgeRepository? fridgeRepository}) {
    return _pending ??= _refresh(fridgeRepository: fridgeRepository);
  }

  static Future<void> _refresh({FridgeRepository? fridgeRepository}) async {
    final repository = fridgeRepository ?? const SupabaseFridgeRepository();
    try {
      items.value = await repository.fetchItems();
    } catch (_) {
      // Leave prior items in place; the Fridge page surfaces its own error.
    } finally {
      _pending = null;
    }
  }
}
