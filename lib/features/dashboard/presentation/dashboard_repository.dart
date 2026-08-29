import '../../../core/supabase/supabase_client.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.displayName,
    required this.streakDays,
    required this.bestStreak,
    required this.points,
    required this.residentialArea,
  });

  final String displayName;
  final int streakDays;
  final int bestStreak;
  final int points;
  final String? residentialArea;
}

/// Reads the signed-in user's profile and stats for the dashboard header,
/// streak card, and profile page. Person 3 (Quests) owns writes to
/// user_stats as streaks and points change; this only reads that table.
class DashboardRepository {
  const DashboardRepository();

  Future<DashboardSummary> fetchSummary() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('No signed-in user when fetching dashboard summary.');
    }

    final profileRow = await supabase
        .from('profiles')
        .select('display_name, residential_area')
        .eq('id', userId)
        .single();

    final statsRow = await supabase
        .from('user_stats')
        .select('streak_days, best_streak, points')
        .eq('user_id', userId)
        .single();

    return DashboardSummary(
      displayName: profileRow['display_name'] as String,
      residentialArea: profileRow['residential_area'] as String?,
      streakDays: statsRow['streak_days'] as int,
      bestStreak: statsRow['best_streak'] as int,
      points: statsRow['points'] as int,
    );
  }

  Future<void> updateResidentialArea(String residentialArea) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('No signed-in user when updating residential area.');
    }

    await supabase
        .from('profiles')
        .update({'residential_area': residentialArea})
        .eq('id', userId);
  }
}