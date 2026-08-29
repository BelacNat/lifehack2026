import 'package:flutter/material.dart';

import '../../data/friend_request_store.dart';

// Owner: Person 3 — Gamification
class AddFriendButton extends StatelessWidget {
  const AddFriendButton({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: FriendRequestStore.friendUserIds,
      builder: (context, friends, _) {
        if (friends.contains(userId)) {
          return OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.people),
            label: const Text('Friend'),
          );
        }

        return ValueListenableBuilder<Set<String>>(
          valueListenable: FriendRequestStore.outgoingRequestUserIds,
          builder: (context, requested, _) {
            final isRequested = requested.contains(userId);
            return OutlinedButton.icon(
              onPressed: () => FriendRequestStore.toggleRequest(userId),
              icon: Icon(isRequested ? Icons.check : Icons.person_add_alt_1),
              label: Text(isRequested ? 'Requested' : 'Add friend'),
            );
          },
        );
      },
    );
  }
}
