import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Owner: Person 3 — Gamification
//
// Local on-device persistence for quest completions, so claimed quests
// stay dismissed and points stay credited across app restarts. This isn't
// backed by Supabase yet — see the open question about auth in the
// gamification schema migration before this can sync across devices.
class QuestPointsStore {
  const QuestPointsStore._();

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
  }
}
