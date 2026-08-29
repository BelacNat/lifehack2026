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
}
