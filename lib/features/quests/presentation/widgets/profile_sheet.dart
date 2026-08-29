import 'package:flutter/material.dart';

import '../../data/friend_request_store.dart';
import '../../data/mock_leaderboard_data.dart';
import '../../domain/leaderboard_entry.dart';

// Owner: Person 3 — Gamification
Future<void> showProfileSheet(BuildContext context, LeaderboardEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ProfileSheet(entry: entry),
  );
}

class ProfileSheet extends StatelessWidget {
  const ProfileSheet({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    entry.avatarEmoji,
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.township,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.userId != currentUserId) ...[
                  const SizedBox(width: 8),
                  _AddFriendButton(entry: entry),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Lifetime points',
                    value: '${entry.lifetimePoints}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Last week rank',
                    value: entry.lastWeekRank != null
                        ? '#${entry.lastWeekRank}'
                        : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${entry.itemsRescued} items rescued · ${entry.itemsWasted} wasted this period',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFriendButton extends StatelessWidget {
  const _AddFriendButton({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: FriendRequestStore.friendUserIds,
      builder: (context, friends, _) {
        if (friends.contains(entry.userId)) {
          return OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.people),
            label: const Text('Friend'),
          );
        }

        return ValueListenableBuilder<Set<String>>(
          valueListenable: FriendRequestStore.outgoingRequestUserIds,
          builder: (context, requested, _) {
            final isRequested = requested.contains(entry.userId);
            return OutlinedButton.icon(
              onPressed: () => FriendRequestStore.toggleRequest(entry.userId),
              icon: Icon(isRequested ? Icons.check : Icons.person_add_alt_1),
              label: Text(isRequested ? 'Requested' : 'Add friend'),
            );
          },
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
