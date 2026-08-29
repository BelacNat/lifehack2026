import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/supabase/supabase_client.dart';
import 'points_service.dart';

// Owner: Person 3 — Gamification
//
// Local on-device persistence for quest completions and immediate bonus-point
// UI updates. Storage is scoped to the real signed-in Supabase user, even
// though the demo leaderboard still uses `u1` as the visual slot for "me".
class QuestPointsStore {
  const QuestPointsStore._();

  static const PointsService _pointsService = PointsService();

  static const _claimedKey = 'quest_points_store.claimed_quest_ids';
  static const _bonusKey = 'quest_points_store.bonus_points_by_user_id';

  static final ValueNotifier<Set<String>> claimedQuestIds =
      ValueNotifier<Set<String>>({});

  static final ValueNotifier<Map<String, int>> bonusPointsByUserId =
      ValueNotifier<Map<String, int>>({});

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

    _loadedUserId = userId;
    claimedQuestIds.value = {};
    bonusPointsByUserId.value = {};
    _loading = _load(userId);
    return _loading!;
  }

  static String _scopedKey(String baseKey, String? userId) {
    return '$baseKey.${userId ?? 'signed_out'}';
  }

  static Future<void> _load(String? userId) async {
    final prefs = await SharedPreferences.getInstance();

    claimedQuestIds.value =
        (prefs.getStringList(_scopedKey(_claimedKey, userId)) ?? const [])
            .toSet();

    final bonusJson = prefs.getString(_scopedKey(_bonusKey, userId));
    if (bonusJson != null) {
      final decoded = jsonDecode(bonusJson) as Map<String, dynamic>;
      bonusPointsByUserId.value = decoded.map(
        (visualUserId, points) => MapEntry(visualUserId, points as int),
      );
    }
  }

  static bool isClaimed(String questId) =>
      claimedQuestIds.value.contains(questId);

  static Future<void> claim(String userId, String questId, int points) async {
    await ensureLoaded();
    if (isClaimed(questId)) return;

    claimedQuestIds.value = {...claimedQuestIds.value, questId};
    bonusPointsByUserId.value = {
      ...bonusPointsByUserId.value,
      userId: (bonusPointsByUserId.value[userId] ?? 0) + points,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scopedKey(_claimedKey, _loadedUserId),
      claimedQuestIds.value.toList(),
    );
    await prefs.setString(
      _scopedKey(_bonusKey, _loadedUserId),
      jsonEncode(bonusPointsByUserId.value),
    );

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
    await ensureLoaded();
    bonusPointsByUserId.value = {
      ...bonusPointsByUserId.value,
      userId: (bonusPointsByUserId.value[userId] ?? 0) + points,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_bonusKey, _loadedUserId),
      jsonEncode(bonusPointsByUserId.value),
    );
  }

  /// Clears the accumulated bonus for a user once a fresh point total has
  /// been fetched from Supabase (which already includes every point ever
  /// synced) — otherwise bonus points from a previous session would be
  /// double-counted on top of the new total.
  static Future<void> resetBonusFor(String userId) async {
    await ensureLoaded();
    if (!bonusPointsByUserId.value.containsKey(userId)) return;

    bonusPointsByUserId.value = {...bonusPointsByUserId.value}..remove(userId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_bonusKey, _loadedUserId),
      jsonEncode(bonusPointsByUserId.value),
    );
  }
}
