import 'food_usage_event.dart';

// Owner: Person 3 — Gamification
//
// Scoring rule: food used on or before its (AI-estimated) expiration date
// earns a flat number of points, regardless of how early. Food used after
// expiry earns nothing.
class PointsCalculator {
  const PointsCalculator._();

  static const int pointsPerRescue = 10;

  static int pointsFor(FoodUsageEvent event) {
    return event.usedBeforeExpiry ? pointsPerRescue : 0;
  }

  /// Points for rescuing an item of the given fridge category, weighted by
  /// typical shelf life — short-shelf-life food (produce, seafood) scores
  /// higher than long-shelf-life food (pantry, condiments), since rescuing
  /// it took more attentiveness.
  static int pointsForCategory(String category) {
    switch (category) {
      case 'produce':
      case 'seafood':
        return 20;
      case 'meat':
        return 18;
      case 'dairy':
      case 'bakery':
        return 15;
      case 'beverage':
        return 8;
      case 'frozen':
        return 6;
      case 'condiment':
      case 'pantry':
        return 5;
      default:
        return 10;
    }
  }
}
