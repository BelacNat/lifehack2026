import '../domain/quest.dart';

// Owner: Person 3 — Gamification
//
// Stand-in for real quest progress until it's tracked against actual fridge
// activity (Person 2) and persisted in Supabase.
List<Quest> loadMockQuests() => const [
      Quest(
        id: 'q1',
        title: 'Rescue 3 items before they expire',
        emoji: '🥦',
        progress: 1,
        pointsReward: 30,
        timeLeft: Duration(hours: 9, minutes: 22),
      ),
      Quest(
        id: 'q2',
        title: 'Try a leftover recipe suggestion',
        emoji: '🍲',
        progress: 1,
        pointsReward: 20,
        timeLeft: Duration(hours: 9, minutes: 22),
      ),
      Quest(
        id: 'q3',
        title: 'Log a fridge item every day for 5 days',
        emoji: '📦',
        progress: 0.6,
        pointsReward: 50,
        timeLeft: Duration(days: 2, hours: 9, minutes: 22),
      ),
      Quest(
        id: 'q4',
        title: 'Invite a friend to EcoHabit',
        emoji: '🤝',
        progress: 0,
        pointsReward: 40,
        timeLeft: Duration(days: 5),
      ),
    ];
