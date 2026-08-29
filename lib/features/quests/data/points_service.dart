import '../../../core/supabase/supabase_client.dart';

// Owner: Person 3 — Gamification
//
// Client for the `award_food_rescue_points` Supabase RPC. Other features
// (e.g. Fridge's "I ate this" action) call this to credit the signed-in
// user's point total when they rescue food before it expires.
class PointsService {
  const PointsService();

  Future<void> awardFoodRescuePoints({
    required String itemName,
    required int points,
  }) {
    return supabase.rpc('award_food_rescue_points', params: {
      'p_item_name': itemName,
      'p_points': points,
    });
  }

  Future<void> awardQuestPoints({
    required String questId,
    required int points,
  }) {
    return supabase.rpc('award_quest_points', params: {
      'p_quest_id': questId,
      'p_points': points,
    });
  }
}
