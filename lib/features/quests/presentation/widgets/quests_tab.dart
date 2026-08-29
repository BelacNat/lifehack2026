import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/mock_quests_data.dart';
import '../../data/quest_points_store.dart';
import '../../domain/quest.dart';
import 'quest_card.dart';

// Owner: Person 3 — Gamification
class QuestsTab extends StatefulWidget {
  const QuestsTab({super.key, required this.currentUserId});

  final String currentUserId;

  @override
  State<QuestsTab> createState() => _QuestsTabState();
}

class _QuestsTabState extends State<QuestsTab>
    with AutomaticKeepAliveClientMixin {
  static const _fadeDelay = Duration(seconds: 1);
  static const _fadeDuration = Duration(milliseconds: 400);

  // Seeded synchronously so a tab that's already loaded once doesn't
  // flash claimed quests back in before the async check below settles.
  late final Set<String> _dismissedQuestIds = {
    ...QuestPointsStore.claimedQuestIds.value,
  };

  // Without this, TabBarView disposes this tab's State whenever you swipe
  // or tap away from it and rebuilds it fresh when you come back — which
  // wiped _dismissedQuestIds and replayed the collapse animation for
  // quests that were already gone.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    QuestPointsStore.ensureLoaded().then((_) {
      if (!mounted) return;
      // Quests claimed in a previous session should already be gone —
      // no re-animating them in just to fade them straight back out.
      setState(
        () => _dismissedQuestIds.addAll(QuestPointsStore.claimedQuestIds.value),
      );
    });
  }

  void _claim(Quest quest) {
    QuestPointsStore.claim(widget.currentUserId, quest.id, quest.pointsReward);
    Timer(_fadeDelay, () {
      if (!mounted) return;
      setState(() => _dismissedQuestIds.add(quest.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final quests = loadMockQuests();

    return ValueListenableBuilder<Set<String>>(
      valueListenable: QuestPointsStore.claimedQuestIds,
      builder: (context, claimed, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: quests.map((quest) {
            final dismissed = _dismissedQuestIds.contains(quest.id);
            return AnimatedOpacity(
              key: ValueKey(quest.id),
              opacity: dismissed ? 0 : 1,
              duration: _fadeDuration,
              child: AnimatedSize(
                duration: _fadeDuration,
                curve: Curves.easeInOut,
                child: dismissed
                    ? const SizedBox.shrink()
                    : QuestCard(
                        quest: quest,
                        claimed: claimed.contains(quest.id),
                        onClaim: () => _claim(quest),
                      ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
