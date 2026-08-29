import '../domain/food_usage_event.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/points_calculator.dart';

// Owner: Person 3 — Gamification
//
// Stand-in for real data while the fridge AI expiry-scraping pipeline
// (Person 2) and Supabase persistence aren't wired up yet. Swap this for a
// repository that reads real FoodUsageEvents once that's ready — the
// scoring and ranking logic below doesn't need to change.
class _MockUser {
  const _MockUser(
    this.userId,
    this.displayName,
    this.avatarEmoji,
    this.township,
    this.monthlyPoints,
    this.lifetimePoints,
    this.lastWeekRank,
  );
  final String userId;
  final String displayName;
  final String avatarEmoji;
  final String township;
  final int monthlyPoints;
  final int lifetimePoints;
  final int? lastWeekRank;
}

/// Stand-in for the logged-in user until auth lands.
const String currentUserId = 'u1';

const _mockUsers = [
  _MockUser('u1', 'Priya', '🥦', 'Bishan', 150, 1180, 3),
  _MockUser('u2', 'Marcus', '🍋', 'Toa Payoh', 70, 340, 8),
  _MockUser('u3', 'Ling', '🥑', 'Bishan', 210, 2065, 2),
  _MockUser('u4', 'Sofia', '🍓', 'Bishan', 130, 890, 5),
  _MockUser('u5', 'Devon', '🥕', 'Changi', 40, 95, null),
  _MockUser('u6', 'Wei', '🍉', 'Tampines', 90, 410, 7),
  _MockUser('u7', 'Aisyah', '🍇', 'Bishan', 185, 1520, 4),
  _MockUser('u8', 'Kai', '🍑', 'Jurong East', 55, 260, 9),
  _MockUser('u9', 'Meera', '🍍', 'Ang Mo Kio', 240, 1890, 1),
  _MockUser('u10', 'Farid', '🥭', 'Punggol', 15, 80, null),
  _MockUser('u11', 'Hui Min', '🍒', 'Bishan', 95, 430, 6),
];

DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

final Map<String, List<FoodUsageEvent>> _mockEventsByUser = {
  'u1': [
    FoodUsageEvent(
        foodName: 'Spinach', usedAt: _daysAgo(1), expiresAt: _daysAgo(0)),
    FoodUsageEvent(
        foodName: 'Yogurt', usedAt: _daysAgo(3), expiresAt: _daysAgo(1)),
    FoodUsageEvent(
        foodName: 'Chicken breast',
        usedAt: _daysAgo(2),
        expiresAt: _daysAgo(1)),
    FoodUsageEvent(
        foodName: 'Bread', usedAt: _daysAgo(5), expiresAt: _daysAgo(4)),
  ],
  'u2': [
    FoodUsageEvent(
        foodName: 'Milk', usedAt: _daysAgo(4), expiresAt: _daysAgo(5)),
    FoodUsageEvent(
        foodName: 'Berries', usedAt: _daysAgo(2), expiresAt: _daysAgo(0)),
  ],
  'u3': [
    FoodUsageEvent(
        foodName: 'Avocado', usedAt: _daysAgo(1), expiresAt: _daysAgo(2)),
    FoodUsageEvent(
        foodName: 'Tofu', usedAt: _daysAgo(6), expiresAt: _daysAgo(1)),
    FoodUsageEvent(
        foodName: 'Rice', usedAt: _daysAgo(10), expiresAt: _daysAgo(3)),
    FoodUsageEvent(
        foodName: 'Carrots', usedAt: _daysAgo(3), expiresAt: _daysAgo(1)),
    FoodUsageEvent(
        foodName: 'Eggs', usedAt: _daysAgo(7), expiresAt: _daysAgo(2)),
  ],
  'u4': [
    FoodUsageEvent(
        foodName: 'Strawberries', usedAt: _daysAgo(1), expiresAt: _daysAgo(1)),
    FoodUsageEvent(
        foodName: 'Leftover pasta',
        usedAt: _daysAgo(2),
        expiresAt: _daysAgo(3)),
    FoodUsageEvent(
        foodName: 'Cheese', usedAt: _daysAgo(8), expiresAt: _daysAgo(2)),
  ],
  'u5': [
    FoodUsageEvent(
        foodName: 'Broccoli', usedAt: _daysAgo(2), expiresAt: _daysAgo(3)),
  ],
  'u6': [
    FoodUsageEvent(
        foodName: 'Tomatoes', usedAt: _daysAgo(1), expiresAt: _daysAgo(0)),
    FoodUsageEvent(
        foodName: 'Oat milk', usedAt: _daysAgo(4), expiresAt: _daysAgo(3)),
  ],
  'u7': [
    FoodUsageEvent(
        foodName: 'Grapes', usedAt: _daysAgo(1), expiresAt: _daysAgo(0)),
    FoodUsageEvent(
        foodName: 'Hummus', usedAt: _daysAgo(2), expiresAt: _daysAgo(1)),
    FoodUsageEvent(
        foodName: 'Tofu', usedAt: _daysAgo(5), expiresAt: _daysAgo(4)),
    FoodUsageEvent(
        foodName: 'Bread', usedAt: _daysAgo(3), expiresAt: _daysAgo(5)),
  ],
  'u8': [
    FoodUsageEvent(
        foodName: 'Peaches', usedAt: _daysAgo(1), expiresAt: _daysAgo(0)),
    FoodUsageEvent(
        foodName: 'Milk', usedAt: _daysAgo(2), expiresAt: _daysAgo(4)),
  ],
  'u9': [
    FoodUsageEvent(
        foodName: 'Pineapple', usedAt: _daysAgo(1), expiresAt: _daysAgo(0)),
    FoodUsageEvent(
        foodName: 'Chicken thigh', usedAt: _daysAgo(2), expiresAt: _daysAgo(1)),
    FoodUsageEvent(
        foodName: 'Spinach', usedAt: _daysAgo(3), expiresAt: _daysAgo(2)),
    FoodUsageEvent(
        foodName: 'Yogurt', usedAt: _daysAgo(4), expiresAt: _daysAgo(3)),
    FoodUsageEvent(
        foodName: 'Eggs', usedAt: _daysAgo(6), expiresAt: _daysAgo(5)),
  ],
  'u10': [
    FoodUsageEvent(
        foodName: 'Bananas', usedAt: _daysAgo(2), expiresAt: _daysAgo(4)),
    FoodUsageEvent(
        foodName: 'Cream', usedAt: _daysAgo(1), expiresAt: _daysAgo(3)),
  ],
  'u11': [
    FoodUsageEvent(
        foodName: 'Cherries', usedAt: _daysAgo(1), expiresAt: _daysAgo(0)),
    FoodUsageEvent(
        foodName: 'Basil', usedAt: _daysAgo(3), expiresAt: _daysAgo(2)),
    FoodUsageEvent(
        foodName: 'Fish fillet', usedAt: _daysAgo(2), expiresAt: _daysAgo(3)),
  ],
};

List<LeaderboardEntry> loadMockLeaderboard() {
  return _mockUsers.map((user) {
    final events = _mockEventsByUser[user.userId] ?? const [];
    var weeklyPoints = 0;
    var rescued = 0;
    var wasted = 0;

    for (final event in events) {
      weeklyPoints += PointsCalculator.pointsFor(event);
      if (event.usedBeforeExpiry) {
        rescued++;
      } else {
        wasted++;
      }
    }

    return LeaderboardEntry(
      userId: user.userId,
      displayName: user.displayName,
      avatarEmoji: user.avatarEmoji,
      township: user.township,
      weeklyPoints: weeklyPoints,
      monthlyPoints: user.monthlyPoints,
      itemsRescued: rescued,
      itemsWasted: wasted,
      lifetimePoints: user.lifetimePoints,
      lastWeekRank: user.lastWeekRank,
    );
  }).toList();
}
