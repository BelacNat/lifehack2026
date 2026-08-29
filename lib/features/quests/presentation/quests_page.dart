import 'package:flutter/material.dart';

import '../data/friend_request_store.dart';
import '../data/mock_leaderboard_data.dart';
import '../data/quest_points_store.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/leaderboard_filters.dart';
import 'widgets/friend_requests_sheet.dart';
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

class _QuestsPageState extends State<QuestsPage> {
  // TODO: replace mock data with real FoodUsageEvents once fridge AI
  // expiry scraping (Person 2) and Supabase persistence are wired up.
  final List<LeaderboardEntry> _allEntries = loadMockLeaderboard();

  LeaderboardScope _scope = LeaderboardScope.overall;
  LeaderboardPeriod _period = LeaderboardPeriod.weekly;

  @override
  void initState() {
    super.initState();
    QuestPointsStore.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            ValueListenableBuilder<Set<String>>(
              valueListenable: FriendRequestStore.incomingRequestUserIds,
              builder: (context, incoming, _) {
                return IconButton(
                  tooltip: 'Friend requests',
                  onPressed: () =>
                      showFriendRequestsSheet(context, _allEntries),
                  icon: Badge(
                    isLabelVisible: incoming.isNotEmpty,
                    label: Text('${incoming.length}'),
                    child: const Icon(Icons.person),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.emoji_events), text: 'Leaderboard'),
              Tab(icon: Icon(Icons.checklist), text: 'Quests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLeaderboardTab(context),
            const QuestsTab(currentUserId: currentUserId),
          ],
        ),
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
                      segments: [
                        const ButtonSegment(
                          value: LeaderboardScope.overall,
                          label: Text('Overall'),
                        ),
                        ButtonSegment(
                          value: LeaderboardScope.township,
                          label: Text(me.township),
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
                      segments: const [
                        ButtonSegment(
                          value: LeaderboardPeriod.weekly,
                          label: Text('Weekly'),
                        ),
                        ButtonSegment(
                          value: LeaderboardPeriod.monthly,
                          label: Text('Monthly'),
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
