import 'package:flutter/material.dart';

import '../data/current_user_profile.dart';
import '../data/friend_request_store.dart';
import '../data/mock_leaderboard_data.dart';
import '../data/quest_points_store.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/leaderboard_filters.dart';
import 'widgets/friends_tab.dart';
import 'widgets/leaderboard_list.dart';
import 'widgets/period_countdown.dart';
import 'widgets/quests_tab.dart';

// Owner: Person 3 — Gamification
// Build here: daily quests, EcoPoints, streaks, levels/tree progression.
// Only edit files under lib/features/quests.
class QuestsPage extends StatefulWidget {
  const QuestsPage({super.key});

  @override
  State<QuestsPage> createState() => _QuestsPageState();
}

class _QuestsPageState extends State<QuestsPage>
    with SingleTickerProviderStateMixin {
  // TODO: replace mock data with real FoodUsageEvents once fridge AI
  // expiry scraping (Person 2) and Supabase persistence are wired up.
  final List<LeaderboardEntry> _mockEntries = loadMockLeaderboard();

  late final TabController _tabController;
  CurrentUserProfile? _me;

  LeaderboardScope _scope = LeaderboardScope.overall;
  LeaderboardPeriod _period = LeaderboardPeriod.weekly;

  /// The mock leaderboard opponents, with the current user's own entry
  /// replaced by their real signed-in profile (name, township, points) so
  /// it matches the "Hey, {name}" identity shown on the Dashboard.
  List<LeaderboardEntry> get _allEntries {
    final me = _me;
    if (me == null) return _mockEntries;
    return _mockEntries.map((e) {
      if (e.userId != currentUserId) return e;
      return LeaderboardEntry(
        userId: e.userId,
        displayName: me.displayName,
        avatarEmoji: me.avatarEmoji,
        township: me.township,
        weeklyPoints: me.weeklyPoints,
        monthlyPoints: me.monthlyPoints,
        itemsRescued: e.itemsRescued,
        itemsWasted: e.itemsWasted,
        lifetimePoints: me.lifetimePoints,
        lastWeekRank: me.hasWeekOfHistory ? e.lastWeekRank : null,
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    QuestPointsStore.ensureLoaded();
    loadCurrentUserProfile().then((profile) async {
      if (profile == null) return;
      // The fresh total already includes every point ever synced, so any
      // locally-accumulated bonus from a prior session would double-count.
      await QuestPointsStore.resetBonusFor(currentUserId);
      if (!mounted) return;
      setState(() => _me = profile);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.emoji_events), text: 'Leaderboard'),
            const Tab(icon: Icon(Icons.checklist), text: 'Quests'),
            Tab(
              text: 'Friends',
              icon: ValueListenableBuilder<Set<String>>(
                valueListenable: FriendRequestStore.incomingRequestUserIds,
                builder: (context, incoming, _) {
                  return Badge(
                    isLabelVisible: incoming.isNotEmpty,
                    label: Text('${incoming.length}'),
                    child: const Icon(Icons.group),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardTab(context),
          const QuestsTab(currentUserId: currentUserId),
          FriendsTab(entries: _allEntries),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab(BuildContext context) {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: QuestPointsStore.bonusPointsByUserId,
      builder: (context, bonusByUserId, _) {
        final entries = _allEntries
            .map((e) => e.withBonusPoints(bonusByUserId[e.userId] ?? 0))
            .toList();
        final me = entries.firstWhere((e) => e.userId == currentUserId);

        final scoped = _scope == LeaderboardScope.township
            ? entries.where((e) => e.township == me.township).toList()
            : List.of(entries);

        scoped.sort((a, b) => _pointsFor(b).compareTo(_pointsFor(a)));

        return Column(
          children: [
            const _PointsRuleBanner(),
            if (_period == LeaderboardPeriod.weekly)
              const PeriodCountdown(
                endOfPeriod: endOfWeek,
                label: 'left this week',
              )
            else
              const PeriodCountdown(
                endOfPeriod: endOfMonth,
                label: 'left this month',
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<LeaderboardScope>(
                      showSelectedIcon: false,
                      segments: [
                        const ButtonSegment(
                          value: LeaderboardScope.overall,
                          label: _SegmentLabel('Overall'),
                        ),
                        ButtonSegment(
                          value: LeaderboardScope.township,
                          label: _SegmentLabel(me.township),
                        ),
                      ],
                      selected: {_scope},
                      onSelectionChanged: (selection) =>
                          setState(() => _scope = selection.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SegmentedButton<LeaderboardPeriod>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: LeaderboardPeriod.weekly,
                          label: _SegmentLabel('Weekly'),
                        ),
                        ButtonSegment(
                          value: LeaderboardPeriod.monthly,
                          label: _SegmentLabel('Monthly'),
                        ),
                      ],
                      selected: {_period},
                      onSelectionChanged: (selection) =>
                          setState(() => _period = selection.first),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LeaderboardList(entries: scoped, period: _period),
            ),
          ],
        );
      },
    );
  }

  int _pointsFor(LeaderboardEntry entry) => _period == LeaderboardPeriod.weekly
      ? entry.weeklyPoints
      : entry.monthlyPoints;
}

/// Keeps segmented-button labels on a single line, shrinking to fit instead
/// of wrapping (e.g. a long township name like "Ang Mo Kio").
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}

class _PointsRuleBanner extends StatelessWidget {
  const _PointsRuleBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⏳', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Race the expiry date, not each other — rescue food before it '
              'turns and the points are yours. Let it expire, and it\'s '
              'worth nothing.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
