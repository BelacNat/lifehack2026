import 'package:flutter/material.dart';

import '../../data/friend_request_store.dart';
import '../../domain/leaderboard_entry.dart';
import 'profile_sheet.dart';

// Owner: Person 3 — Gamification
//
// Friend requests and the friends list, in one tab.
class FriendsTab extends StatelessWidget {
  const FriendsTab({super.key, required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        FriendRequestStore.incomingRequestUserIds,
        FriendRequestStore.friendUserIds,
      ]),
      builder: (context, _) {
        final incoming = entries
            .where((e) => FriendRequestStore.incomingRequestUserIds.value
                .contains(e.userId))
            .toList();
        final friends = entries
            .where((e) =>
                FriendRequestStore.friendUserIds.value.contains(e.userId))
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _Section(
              title: 'Friend requests',
              emptyLabel: 'No pending friend requests.',
              entries: incoming,
              trailingBuilder: (entry) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () =>
                        FriendRequestStore.acceptIncoming(entry.userId),
                    icon: const Icon(Icons.check_circle),
                    color: Theme.of(context).colorScheme.primary,
                    tooltip: 'Accept',
                  ),
                  IconButton(
                    onPressed: () =>
                        FriendRequestStore.rejectIncoming(entry.userId),
                    icon: const Icon(Icons.cancel),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: 'Reject',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _Section(
              title: 'Friends',
              emptyLabel: 'No friends yet — accept a request to get started.',
              entries: friends,
              onTapEntry: (entry) => showProfileSheet(context, entry),
              trailingBuilder: (entry) => Icon(
                Icons.people,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.emptyLabel,
    required this.entries,
    required this.trailingBuilder,
    this.onTapEntry,
  });

  final String title;
  final String emptyLabel;
  final List<LeaderboardEntry> entries;
  final Widget Function(LeaderboardEntry entry) trailingBuilder;
  final ValueChanged<LeaderboardEntry>? onTapEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...entries.map((entry) => _PersonRow(
                entry: entry,
                trailing: trailingBuilder(entry),
                onTap: onTapEntry == null ? null : () => onTapEntry!(entry),
              )),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.entry, required this.trailing, this.onTap});

  final LeaderboardEntry entry;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final row = Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(entry.avatarEmoji, style: const TextStyle(fontSize: 18)),
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
        trailing,
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: row,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: row,
        ),
      ),
    );
  }
}
