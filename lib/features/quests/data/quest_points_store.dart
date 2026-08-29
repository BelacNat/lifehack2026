import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'points_service.dart';

// Owner: Person 3 — Gamification
//
// Local on-device persistence for quest completions, so claimed quests
// stay dismissed and points stay credited across app restarts. The bonus
// totals also sync to Supabase (points_ledger + user_stats.points) via
// PointsService — best-effort, since the local claim above is already the
// source of truth for this device's UI.
class QuestPointsStore {
  const QuestPointsStore._();

  static const PointsService _pointsService = PointsService();

  static const _claimedKey = 'quest_points_store.claimed_quest_ids';
  static const _bonusKey = 'quest_points_store.bonus_points_by_user_id';

  static final ValueNotifier<Set<String>> claimedQuestIds =
      ValueNotifier<Set<String>>({});

  static final ValueNotifier<Map<String, int>> bonusPointsByUserId =
      ValueNotifier<Map<String, int>>({});

  static Future<void>? _loading;

  /// Loads persisted state on first call; safe to call repeatedly.
  static Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    claimedQuestIds.value =
        (prefs.getStringList(_claimedKey) ?? const []).toSet();

    final bonusJson = prefs.getString(_bonusKey);
    if (bonusJson != null) {
      final decoded = jsonDecode(bonusJson) as Map<String, dynamic>;
      bonusPointsByUserId.value = decoded.map(
        (userId, points) => MapEntry(userId, points as int),
      );
    }
  }

  static bool isClaimed(String questId) =>
      claimedQuestIds.value.contains(questId);

  static Future<void> claim(String userId, String questId, int points) async {
    if (isClaimed(questId)) return;

    claimedQuestIds.value = {...claimedQuestIds.value, questId};
    bonusPointsByUserId.value = {
      ...bonusPointsByUserId.value,
      userId: (bonusPointsByUserId.value[userId] ?? 0) + points,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_claimedKey, claimedQuestIds.value.toList());
    await prefs.setString(_bonusKey, jsonEncode(bonusPointsByUserId.value));

    try {
      await _pointsService.awardQuestPoints(questId: questId, points: points);
    } catch (_) {
      // The local claim above already updated this device's UI; a failed
      // sync just means the real point total catches up on a later claim.
    }
  }

  /// Credits bonus points from a source other than a quest claim (e.g. the
  /// Fridge's "I ate this" action), so the leaderboard reflects it
  /// immediately without a full leaderboard reload.
  static Future<void> addBonusPoints(String userId, int points) async {
    bonusPointsByUserId.value = {
      ...bonusPointsByUserId.value,
      userId: (bonusPointsByUserId.value[userId] ?? 0) + points,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bonusKey, jsonEncode(bonusPointsByUserId.value));
  }

  /// Clears the accumulated bonus for a user once a fresh point total has
  /// been fetched from Supabase (which already includes every point ever
  /// synced) — otherwise bonus points from a previous session would be
  /// double-counted on top of the new total.
  static Future<void> resetBonusFor(String userId) async {
    if (!bonusPointsByUserId.value.containsKey(userId)) return;

    bonusPointsByUserId.value = {...bonusPointsByUserId.value}..remove(userId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bonusKey, jsonEncode(bonusPointsByUserId.value));
  }
}
