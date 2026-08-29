// Owner: Person 3 — Gamification
//
// A single "food used" event, scored for the leaderboard. `expiresAt` is
// expected to come from Person 2's fridge AI scraping of average shelf life
// per food item — for now it's supplied directly (see mock_leaderboard_data.dart)
// until that integration lands.
class FoodUsageEvent {
  const FoodUsageEvent({
    required this.foodName,
    required this.usedAt,
    required this.expiresAt,
  });

  final String foodName;
  final DateTime usedAt;
  final DateTime expiresAt;

  bool get usedBeforeExpiry => !usedAt.isAfter(expiresAt);
}
