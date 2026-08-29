import 'package:flutter/material.dart';

import '../../data/friend_request_store.dart';
import '../../domain/leaderboard_entry.dart';

// Owner: Person 3 — Gamification
Future<void> showFriendRequestsSheet(
  BuildContext context,
  List<LeaderboardEntry> entries,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => FriendRequestsSheet(entries: entries),
  );
}

class FriendRequestsSheet extends StatelessWidget {
  const FriendRequestsSheet({super.key, required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: FriendRequestStore.incomingRequestUserIds,
        builder: (context, incomingIds, _) {
          final requesters =
              entries.where((e) => incomingIds.contains(e.userId)).toList();

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Friend requests',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (requesters.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No pending friend requests.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ...requesters.map((entry) => _RequestRow(entry: entry)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primaryContainer,
            child:
                Text(entry.avatarEmoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  entry.township,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => FriendRequestStore.acceptIncoming(entry.userId),
            icon: const Icon(Icons.check_circle),
            color: theme.colorScheme.primary,
            tooltip: 'Accept',
          ),
          IconButton(
            onPressed: () => FriendRequestStore.rejectIncoming(entry.userId),
            icon: const Icon(Icons.cancel),
            color: theme.colorScheme.error,
            tooltip: 'Reject',
          ),
        ],
      ),
    );
  }
}
