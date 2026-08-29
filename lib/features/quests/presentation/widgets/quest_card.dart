import 'package:flutter/material.dart';

import '../../domain/quest.dart';

// Owner: Person 3 — Gamification
class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.quest,
    required this.claimed,
    required this.onClaim,
  });

  final Quest quest;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canClaim = quest.isComplete && !claimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(quest.emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (quest.timeLeft != null)
                  Text(
                    '${_formatDuration(quest.timeLeft!)} left',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  quest.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: quest.progress.clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surface,
                    color: claimed
                        ? theme.colorScheme.outline
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (claimed)
            Icon(Icons.check_circle, color: theme.colorScheme.primary)
          else if (canClaim)
            FilledButton(
              onPressed: onClaim,
              child: Text('+${quest.pointsReward}'),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${quest.pointsReward}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
