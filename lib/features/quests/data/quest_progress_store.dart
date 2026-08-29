import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/supabase/supabase_client.dart';

// Owner: Person 3 — Gamification
//
// Local on-device tracking of real in-app activity behind each quest. The
// storage keys are scoped to the signed-in Supabase user so switching accounts
// on the same device cannot leak quest progress from one user to another.
class QuestProgressStore {
  const QuestProgressStore._();

  static const _countsKey = 'quest_progress_store.counts';
  static const _activeDatesKey = 'quest_progress_store.active_dates';

  static final ValueNotifier<Map<String, int>> counts =
      ValueNotifier<Map<String, int>>({});

  static Set<String> _activeDates = {};
  static String? _loadedUserId;
  static Future<void>? _loading;

  static String? get _currentUserId {
    try {
      return supabase.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static Future<void> ensureLoaded() {
    final userId = _currentUserId;
    if (_loadedUserId == userId && _loading != null) return _loading!;

    // A different signed-in user should start with a different local cache.
    _loadedUserId = userId;
    counts.value = {};
    _activeDates = {};
    _loading = _load(userId);
    return _loading!;
  }

  static String _scopedKey(String baseKey, String? userId) {
    return '$baseKey.${userId ?? 'signed_out'}';
  }

  static Future<void> _load(String? userId) async {
    final prefs = await SharedPreferences.getInstance();

    final countsJson = prefs.getString(_scopedKey(_countsKey, userId));
    if (countsJson != null) {
      final decoded = jsonDecode(countsJson) as Map<String, dynamic>;
      counts.value = decoded.map(
        (questId, value) => MapEntry(questId, value as int),
      );
    }

    _activeDates = (prefs.getStringList(
              _scopedKey(_activeDatesKey, userId),
            ) ??
            const [])
        .toSet();
  }

  static Future<void> _setCount(String questId, int value) async {
    await ensureLoaded();
    if (counts.value[questId] == value) return;

    counts.value = {...counts.value, questId: value};

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_countsKey, _loadedUserId),
      jsonEncode(counts.value),
    );
  }

  static Future<void> _bump(String questId) async {
    await ensureLoaded();
    await _setCount(questId, (counts.value[questId] ?? 0) + 1);
  }

  /// "I ate this" on an item that had not expired yet.
  static Future<void> recordItemRescued() => _bump('q1');

  /// Completing a rescue recipe.
  static Future<void> recordRecipeCompleted() async {
    await _setCount('q2', 1);
    await _setCount('q5', 1);
  }

  /// Sending a friend request.
  static Future<void> recordFriendRequestSent() => _setCount('q4', 1);

  /// Clearing every item expiring today through a real rescue action.
  static Future<void> recordZeroWasteDay() => _setCount('q6', 1);

  /// A real fridge action today (adding or consuming food), counted once per
  /// local calendar day toward the multi-day activity quest. Merely opening or
  /// refreshing the Fridge page does not count.
  static Future<void> recordFridgeActivityToday() async {
    await ensureLoaded();
    final key = _todayKey();
    if (_activeDates.contains(key)) return;

    _activeDates = {..._activeDates, key};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scopedKey(_activeDatesKey, _loadedUserId),
      _activeDates.toList(),
    );
    await _setCount('q3', _activeDates.length);
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
