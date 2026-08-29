import 'dart:async';

import 'package:flutter/material.dart';

// Owner: Person 3 — Gamification
DateTime endOfWeek(DateTime now) {
  final daysToAdd = 8 - now.weekday;
  return DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
}

DateTime endOfMonth(DateTime now) => DateTime(now.year, now.month + 1, 1);

class PeriodCountdown extends StatefulWidget {
  const PeriodCountdown({
    super.key,
    required this.endOfPeriod,
    required this.label,
  });

  final DateTime Function(DateTime now) endOfPeriod;

  /// Text shown after the countdown, e.g. "left this week".
  final String label;

  @override
  State<PeriodCountdown> createState() => _PeriodCountdownState();
}

class _PeriodCountdownState extends State<PeriodCountdown> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final remaining = widget.endOfPeriod(now).difference(now);
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '${days}d ${hours}h ${minutes}m ${widget.label}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
