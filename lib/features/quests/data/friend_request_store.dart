import 'package:flutter/foundation.dart';

import 'quest_progress_store.dart';

// Owner: Person 3 — Gamification
//
// In-memory stand-in for a real friends/social backend. Tracks outgoing
// friend requests the current user has sent, and incoming ones from other
// users, for this session only.
class FriendRequestStore {
  const FriendRequestStore._();

  /// Users the current user has sent a friend request to.
  static final ValueNotifier<Set<String>> outgoingRequestUserIds =
      ValueNotifier<Set<String>>({});

  /// Users who have sent the current user a friend request, pending a
  /// response. Seeded with a couple of mock requests for demo purposes.
  static final ValueNotifier<Set<String>> incomingRequestUserIds =
      ValueNotifier<Set<String>>({'u3', 'u9'});

  /// Users who have become friends after an incoming request was accepted.
  static final ValueNotifier<Set<String>> friendUserIds =
      ValueNotifier<Set<String>>({});

  static bool isRequested(String userId) =>
      outgoingRequestUserIds.value.contains(userId);

  static bool isFriend(String userId) => friendUserIds.value.contains(userId);

  /// Sends a request if none is pending, or withdraws it if one already is.
  static void toggleRequest(String userId) {
    final current = outgoingRequestUserIds.value;
    final wasRequested = current.contains(userId);
    outgoingRequestUserIds.value =
        wasRequested ? ({...current}..remove(userId)) : {...current, userId};
    if (!wasRequested) QuestProgressStore.recordFriendRequestSent();
  }

  static void acceptIncoming(String userId) {
    incomingRequestUserIds.value = {...incomingRequestUserIds.value}
      ..remove(userId);
    friendUserIds.value = {...friendUserIds.value, userId};
  }

  static void rejectIncoming(String userId) {
    incomingRequestUserIds.value = {...incomingRequestUserIds.value}
      ..remove(userId);
  }
}
