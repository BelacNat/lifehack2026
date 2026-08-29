import '../domain/quest.dart';

// Owner: Person 3 — Gamification
//
// Quest catalog (title/emoji/reward/target) is fixed; progress is computed
// from real activity counts tracked in QuestProgressStore, so quests update
// as their associated requirements are actually done in the app.
class _QuestDef {
  const _QuestDef({
    required this.id,
    required this.title,
    required this.emoji,
    required this.pointsReward,
    required this.target,
    this.timeLeft,
  });

  final String id;
  final String title;
  final String emoji;
  final int pointsReward;
  final int target;
  final Duration? timeLeft;
}

const _questDefs = [
  _QuestDef(
    id: 'q1',
    title: 'Rescue 3 items before they expire',
    emoji: '🥦',
    pointsReward: 20,
    target: 3,
    timeLeft: Duration(hours: 9, minutes: 22),
  ),
  _QuestDef(
    id: 'q2',
    title: 'Try a leftover recipe suggestion',
    emoji: '🍲',
    pointsReward: 10,
    target: 1,
    timeLeft: Duration(hours: 9, minutes: 22),
  ),
  _QuestDef(
    id: 'q3',
    title: 'Log a fridge item every day for 5 days',
    emoji: '📦',
    pointsReward: 40,
    target: 5,
    timeLeft: Duration(days: 2, hours: 9, minutes: 22),
  ),
  _QuestDef(
    id: 'q4',
    title: 'Invite a friend to Fridgewise',
    emoji: '🤝',
    pointsReward: 30,
    target: 1,
    timeLeft: Duration(days: 5),
  ),
  _QuestDef(
    id: 'q5',
    title: 'Finish a recipe using rescued ingredients',
    emoji: '🍽️',
    pointsReward: 15,
    target: 1,
    timeLeft: Duration(hours: 14),
  ),
  _QuestDef(
    id: 'q6',
    title: 'Zero food waste for a full day',
    emoji: '🌱',
    pointsReward: 25,
    target: 1,
    timeLeft: Duration(days: 1, hours: 4),
  ),
];

List<Quest> loadMockQuests(Map<String, int> progressCounts) {
  return _questDefs.map((def) {
    final count = progressCounts[def.id] ?? 0;
    return Quest(
      id: def.id,
      title: def.title,
      emoji: def.emoji,
      pointsReward: def.pointsReward,
      timeLeft: def.timeLeft,
      progress: (count / def.target).clamp(0.0, 1.0),
    );
  }).toList();
}
