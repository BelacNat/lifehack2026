// Owner: Person 3 — Gamification
enum LeaderboardScope {
  overall('Overall'),
  township('Township');

  const LeaderboardScope(this.label);
  final String label;
}

enum LeaderboardPeriod {
  weekly('Weekly'),
  monthly('Monthly');

  const LeaderboardPeriod(this.label);
  final String label;
}
