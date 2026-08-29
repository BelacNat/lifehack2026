import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Owner: Person 3 — Gamification
//
// Local on-device tracking of real in-app activity behind each quest, so
// quest progress reflects what the user actually did (rescued items,
// completed recipes, invited a friend, kept a zero-waste day) instead of
// a fixed mock value. Quest targets live in mock_quests_data.dart, which
// turns these raw counts into each Quest's 0.0–1.0 progress.
class QuestProgressStore {
  const QuestProgressStore._();

  static const _countsKey = 'quest_progress_store.counts';
  static const _activeDatesKey = 'quest_progress_store.active_dates';

  static final ValueNotifier<Map<String, int>> counts =
      ValueNotifier<Map<String, int>>({});

  static Set<String> _activeDates = {};

  static Future<void>? _loading;

  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final countsJson = prefs.getString(_countsKey);
    if (countsJson != null) {
      final decoded = jsonDecode(countsJson) as Map<String, dynamic>;
      counts.value = decoded.map(
        (questId, value) => MapEntry(questId, value as int),
      );
    }

    _activeDates = (prefs.getStringList(_activeDatesKey) ?? const []).toSet();
  }

  static Future<void> _setCount(String questId, int value) async {
    if (counts.value[questId] == value) return;

    counts.value = {...counts.value, questId: value};

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countsKey, jsonEncode(counts.value));
  }

  static Future<void> _bump(String questId) {
    return _setCount(questId, (counts.value[questId] ?? 0) + 1);
  }

  /// "I ate this" on an item that hadn't expired yet.
  static Future<void> recordItemRescued() => _bump('q1');

  /// Completing a rescue recipe.
  static Future<void> recordRecipeCompleted() async {
    await _setCount('q2', 1);
    await _setCount('q5', 1);
  }

  /// Sending a friend request.
  static Future<void> recordFriendRequestSent() => _setCount('q4', 1);

  /// Clearing every item expiring today.
  static Future<void> recordZeroWasteDay() => _setCount('q6', 1);

  /// Any fridge check-in today (loading the fridge, adding or consuming an
  /// item) — counted once per calendar day toward "log a fridge item every
  /// day for 5 days".
  static Future<void> recordFridgeActivityToday() async {
    final key = _todayKey();
    if (_activeDates.contains(key)) return;

    _activeDates = {..._activeDates, key};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_activeDatesKey, _activeDates.toList());
    await _setCount('q3', _activeDates.length);
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
