import '../../../core/supabase/supabase_client.dart';

// Owner: Person 3 — Gamification
//
// Client for the `bump_daily_streak` Supabase RPC. Safe to call more than
// once a day — the function itself no-ops if today's already counted.
class StreakService {
  const StreakService();

  Future<void> bumpDailyStreak() {
    return supabase.rpc('bump_daily_streak');
  }
}
