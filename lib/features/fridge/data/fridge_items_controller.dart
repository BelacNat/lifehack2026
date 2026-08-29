import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/fridge_item.dart';
import 'fridge_repository.dart';

/// Shared store for the signed-in user's fridge items, so other features
/// (currently the Dashboard's "Use these soon" shelf) show the same items as
/// the Fridge page without duplicating the fetch.
///
/// The cache is explicitly scoped to the current Supabase user. This prevents
/// a second account on the same device from briefly seeing the previous
/// account's fridge while a new request is loading.
class FridgeItemsController {
  FridgeItemsController._();

  static final ValueNotifier<List<FridgeItem>> items =
      ValueNotifier<List<FridgeItem>>(const []);

  static String? _loadedUserId;
  static String? _pendingUserId;
  static Future<void>? _pending;

  static String? get _currentUserId {
    try {
      return supabase.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static void _syncUserScope() {
    final userId = _currentUserId;
    if (_loadedUserId == userId) return;

    _loadedUserId = userId;
    items.value = const [];

    // An old request cannot be cancelled, but it is no longer reusable and
    // _refresh() checks the user again before publishing its result.
    _pending = null;
    _pendingUserId = null;
  }

  /// Triggers a load the first time it's called for the current user.
  /// Safe to call repeatedly.
  static Future<void> ensureLoaded({FridgeRepository? fridgeRepository}) {
    _syncUserScope();
    if (items.value.isNotEmpty) return Future.value();
    return refresh(fridgeRepository: fridgeRepository);
  }

  /// Re-fetches regardless of current content — for pull-to-refresh or a
  /// manual retry after a failed load.
  static Future<void> refresh({FridgeRepository? fridgeRepository}) {
    _syncUserScope();
    final userId = _currentUserId;

    if (_pending != null && _pendingUserId == userId) return _pending!;

    _pendingUserId = userId;
    _pending = _refresh(
      userId: userId,
      fridgeRepository: fridgeRepository,
    );
    return _pending!;
  }

  static Future<void> _refresh({
    required String? userId,
    FridgeRepository? fridgeRepository,
  }) async {
    final repository = fridgeRepository ?? const SupabaseFridgeRepository();
    try {
      final fetched = await repository.fetchItems();
      if (_currentUserId == userId) {
        items.value = fetched;
      }
    } catch (_) {
      // Never retain another user's stale cache after an auth change or a
      // failed fetch. The Fridge page surfaces the detailed load error.
      if (_currentUserId == userId) {
        items.value = const [];
      }
    } finally {
      if (_pendingUserId == userId) {
        _pending = null;
        _pendingUserId = null;
      }
    }
  }
}
