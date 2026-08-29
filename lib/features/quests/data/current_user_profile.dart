import '../../../core/supabase/supabase_client.dart';

// Owner: Person 3 — Gamification
//
// Reads the signed-in user's real identity (matching the Dashboard's
// "Hey, {name}" header) so the leaderboard's own entry reflects who's
// actually logged in, instead of a hardcoded mock profile.
class CurrentUserProfile {
  const CurrentUserProfile({
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    required this.township,
    required this.weeklyPoints,
    required this.monthlyPoints,
    required this.lifetimePoints,
    required this.hasWeekOfHistory,
  });

  final String userId;
  final String displayName;
  final String avatarEmoji;
  final String township;

  /// Fresh accounts start at 0 and accumulate as points_ledger rows are
  /// added (food rescued, quests claimed) — these read the same
  /// leaderboard_weekly/monthly/lifetime views everyone else is ranked by.
  final int weeklyPoints;
  final int monthlyPoints;
  final int lifetimePoints;

  /// Whether this account has existed for more than a week — a rank "as
  /// of last week" is meaningless before the account has completed one.
  final bool hasWeekOfHistory;
}

Future<CurrentUserProfile?> loadCurrentUserProfile() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final profileRow = await supabase
      .from('profiles')
      .select('display_name, avatar_emoji, residential_area, created_at')
      .eq('id', userId)
      .maybeSingle();
  if (profileRow == null) return null;

  final createdAt =
      DateTime.tryParse(profileRow['created_at'] as String? ?? '');
  final hasWeekOfHistory = createdAt != null &&
      DateTime.now().difference(createdAt) >= const Duration(days: 7);

  final weeklyRow = await supabase
      .from('leaderboard_weekly')
      .select('points')
      .eq('user_id', userId)
      .maybeSingle();
  final monthlyRow = await supabase
      .from('leaderboard_monthly')
      .select('points')
      .eq('user_id', userId)
      .maybeSingle();
  final lifetimeRow = await supabase
      .from('leaderboard_lifetime')
      .select('points')
      .eq('user_id', userId)
      .maybeSingle();

  return CurrentUserProfile(
    userId: userId,
    displayName: profileRow['display_name'] as String? ?? 'You',
    avatarEmoji: profileRow['avatar_emoji'] as String? ?? '🙂',
    township: profileRow['residential_area'] as String? ?? 'Singapore',
    weeklyPoints: weeklyRow?['points'] as int? ?? 0,
    monthlyPoints: monthlyRow?['points'] as int? ?? 0,
    lifetimePoints: lifetimeRow?['points'] as int? ?? 0,
    hasWeekOfHistory: hasWeekOfHistory,
  );
}
