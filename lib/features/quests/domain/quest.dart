// Owner: Person 3 — Gamification
class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.emoji,
    required this.progress,
    required this.pointsReward,
    this.timeLeft,
  });

  final String id;
  final String title;
  final String emoji;

  /// 0.0 to 1.0.
  final double progress;
  final int pointsReward;

  /// Null means no deadline.
  final Duration? timeLeft;

  bool get isComplete => progress >= 1.0;
}
