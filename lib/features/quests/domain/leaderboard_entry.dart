// Owner: Person 3 — Gamification
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    required this.township,
    required this.weeklyPoints,
    required this.monthlyPoints,
    required this.itemsRescued,
    required this.itemsWasted,
    required this.lifetimePoints,
    required this.lastWeekRank,
  });

  final String userId;
  final String displayName;
  final String avatarEmoji;

  /// Rough Singapore neighbourhood, e.g. "Bishan" or "Toa Payoh".
  final String township;

  /// Points earned in the current week.
  final int weeklyPoints;

  /// Points earned in the current month.
  final int monthlyPoints;
  final int itemsRescued;
  final int itemsWasted;

  /// All-time points, independent of the current leaderboard period.
  final int lifetimePoints;

  /// This user's rank as of last week's leaderboard. Null if they weren't
  /// ranked (e.g. new user).
  final int? lastWeekRank;

  /// Applies quest-reward points earned this session to every points total.
  LeaderboardEntry withBonusPoints(int bonus) {
    if (bonus == 0) return this;
    return LeaderboardEntry(
      userId: userId,
      displayName: displayName,
      avatarEmoji: avatarEmoji,
      township: township,
      weeklyPoints: weeklyPoints + bonus,
      monthlyPoints: monthlyPoints + bonus,
      itemsRescued: itemsRescued,
      itemsWasted: itemsWasted,
      lifetimePoints: lifetimePoints + bonus,
      lastWeekRank: lastWeekRank,
    );
  }
}
