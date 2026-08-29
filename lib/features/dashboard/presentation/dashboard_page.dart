import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_client.dart';
import 'dashboard_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _repository = const DashboardRepository();
  late Future<DashboardSummary> _summaryFuture;

  bool _isInsightExpanded = false;

  final List<_ExpiringItem> _expiringItems = const [
    _ExpiringItem(name: 'Baby spinach', quantity: '1 bag, 120g', urgency: _Urgency.today, icon: Icons.eco),
    _ExpiringItem(name: 'Greek yoghurt', quantity: '450g tub', urgency: _Urgency.today, icon: Icons.icecream_outlined),
    _ExpiringItem(name: 'Vine tomatoes', quantity: '6 pcs', urgency: _Urgency.soon, icon: Icons.circle_outlined),
    _ExpiringItem(name: 'Chicken thigh', quantity: '500g pack', urgency: _Urgency.fresh, icon: Icons.kitchen_outlined),
  ];

  final List<_RecipePreview> _recipes = const [
    _RecipePreview(name: 'Spinach and tomato shakshuka', usesCount: 3, matchPercent: 92),
    _RecipePreview(name: 'Yoghurt-marinated grilled chicken', usesCount: 2, matchPercent: 78),
    _RecipePreview(name: 'Roast tomato and herb pasta', usesCount: 1, matchPercent: 65),
  ];

  final List<_ShoppingTip> _extraShoppingTips = const [
    _ShoppingTip(name: 'Rolled oats', action: _TipAction.buy),
    _ShoppingTip(name: 'Bell peppers', action: _TipAction.buy),
    _ShoppingTip(name: 'Extra milk', action: _TipAction.skip),
  ];

  @override
  void initState() {
    super.initState();
    _summaryFuture = _repository.fetchSummary();
  }

  void _goToInventory() => context.go('/inventory');

  void _goToFridge() => context.go('/fridge');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expiringToday =
        _expiringItems.where((item) => item.urgency == _Urgency.today).length;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<DashboardSummary>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _DashboardError(
                onRetry: () => setState(() {
                  _summaryFuture = _repository.fetchSummary();
                }),
              );
            }

            final summary = snapshot.data!;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(theme: theme, summary: summary),
                ),
                SliverToBoxAdapter(
                  child: _StreakCard(
                    theme: theme,
                    streakDays: summary.streakDays,
                    bestStreak: summary.bestStreak,
                    points: summary.points,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Use these soon',
                    actionLabel: 'See fridge',
                    onAction: _goToFridge,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ExpiringShelf(items: _expiringItems, theme: theme),
                ),
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Fridge at a glance',
                    actionLabel: '${_expiringItems.length} items',
                  ),
                ),
                SliverToBoxAdapter(
                  child: _GlanceGrid(
                    theme: theme,
                    expiringTodayCount: expiringToday,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _AiInsightBanner(
                    theme: theme,
                    isExpanded: _isInsightExpanded,
                    extraTips: _extraShoppingTips,
                    onToggle: () =>
                        setState(() => _isInsightExpanded = !_isInsightExpanded),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Cook with what you have',
                    actionLabel: 'More recipes',
                    onAction: _goToInventory,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _RecipeRow(
                    recipes: _recipes,
                    theme: theme,
                    onRecipeTap: _goToInventory,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Couldn't load your dashboard."),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => supabase.auth.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Urgency { today, soon, fresh }

enum _TipAction { buy, skip }

class _ExpiringItem {
  const _ExpiringItem({
    required this.name,
    required this.quantity,
    required this.urgency,
    required this.icon,
  });

  final String name;
  final String quantity;
  final _Urgency urgency;
  final IconData icon;

  String get daysLabel => switch (urgency) {
        _Urgency.today => 'Expires today',
        _Urgency.soon => '2 days left',
        _Urgency.fresh => '5 days left',
      };

  Color urgencyColor(ColorScheme scheme) => switch (urgency) {
        _Urgency.today => scheme.error,
        _Urgency.soon => Colors.orange.shade700,
        _Urgency.fresh => Colors.green.shade600,
      };
}

class _RecipePreview {
  const _RecipePreview({
    required this.name,
    required this.usesCount,
    required this.matchPercent,
  });

  final String name;
  final int usesCount;
  final int matchPercent;
}

class _ShoppingTip {
  const _ShoppingTip({required this.name, required this.action});

  final String name;
  final _TipAction action;
}

class _Header extends StatelessWidget {
  const _Header({required this.theme, required this.summary});

  final ThemeData theme;
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final initials = summary.displayName.trim().isEmpty
        ? '?'
        : summary.displayName.trim().substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAT, 29 AUG',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hey, ${summary.displayName}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(22),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                initials,
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.theme,
    required this.streakDays,
    required this.bestStreak,
    required this.points,
  });

  final ThemeData theme;
  final int streakDays;
  final int bestStreak;
  final int points;

  static const int _weekLength = 7;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final filledTicks = streakDays.clamp(0, _weekLength);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.local_fire_department,
                color: scheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ZERO-WASTE STREAK',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                      children: [
                        TextSpan(text: '$streakDays days '),
                        TextSpan(
                          text: '· best: $bestStreak',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(_weekLength, (i) {
                      final filled = i < filledTicks;
                      return Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(
                            right: i == _weekLength - 1 ? 0 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: filled
                                ? scheme.tertiary
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    '$points',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'points',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text(
                  actionLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Text(
              actionLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpiringShelf extends StatelessWidget {
  const _ExpiringShelf({required this.items, required this.theme});

  final List<_ExpiringItem> items;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final color = item.urgencyColor(scheme);

          return Container(
            width: 132,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(item.icon, size: 16, color: color),
                ),
                const SizedBox(height: 10),
                Text(
                  item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.quantity,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.daysLabel,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GlanceGrid extends StatelessWidget {
  const _GlanceGrid({required this.theme, required this.expiringTodayCount});

  final ThemeData theme;
  final int expiringTodayCount;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    final tiles = [
      _GlanceTile(icon: Icons.eco_outlined, number: 6, label: 'Fresh produce'),
      _GlanceTile(
        icon: Icons.kitchen_outlined,
        number: 3,
        label: 'Meat and dairy',
      ),
      _GlanceTile(
        icon: Icons.inventory_2_outlined,
        number: 5,
        label: 'Pantry and other',
      ),
      _GlanceTile(
        icon: Icons.warning_amber_rounded,
        number: expiringTodayCount,
        label: 'Expiring today',
        emphasize: true,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: tiles
            .map((tile) => _GlanceCard(tile: tile, scheme: scheme, theme: theme))
            .toList(),
      ),
    );
  }
}

class _GlanceTile {
  const _GlanceTile({
    required this.icon,
    required this.number,
    required this.label,
    this.emphasize = false,
  });

  final IconData icon;
  final int number;
  final String label;
  final bool emphasize;
}

class _GlanceCard extends StatelessWidget {
  const _GlanceCard({
    required this.tile,
    required this.scheme,
    required this.theme,
  });

  final _GlanceTile tile;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final numberColor = tile.emphasize ? scheme.error : scheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: tile.emphasize
            ? Border.all(color: scheme.error.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(tile.icon, size: 18, color: scheme.onSurfaceVariant),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tile.number}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: numberColor,
                ),
              ),
              Text(
                tile.label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiInsightBanner extends StatelessWidget {
  const _AiInsightBanner({
    required this.theme,
    required this.isExpanded,
    required this.extraTips,
    required this.onToggle,
  });

  final ThemeData theme;
  final bool isExpanded;
  final List<_ShoppingTip> extraTips;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.secondary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shopping smarter this week',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "You've restocked spinach 3 weeks running but only "
                        'use half. Try a 120g bag next time, and skip more '
                        'tomatoes — 6 are still sitting unused.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isExpanded ? 'Hide suggestions' : 'View full suggestions',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: scheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        children: extraTips
                            .map((tip) => _ShoppingTipRow(
                                  tip: tip,
                                  theme: theme,
                                  scheme: scheme,
                                ))
                            .toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingTipRow extends StatelessWidget {
  const _ShoppingTipRow({
    required this.tip,
    required this.theme,
    required this.scheme,
  });

  final _ShoppingTip tip;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isBuy = tip.action == _TipAction.buy;
    final tagColor = isBuy ? Colors.green.shade700 : scheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            tip.name,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isBuy ? 'Buy' : 'Skip',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: tagColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({
    required this.recipes,
    required this.theme,
    required this.onRecipeTap,
  });

  final List<_RecipePreview> recipes;
  final ThemeData theme;
  final VoidCallback onRecipeTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recipes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final recipe = recipes[index];

          return InkWell(
            onTap: onRecipeTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 188,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 96,
                    width: double.infinity,
                    color: scheme.surfaceContainerHighest,
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 30,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '${recipe.matchPercent}% match',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.name,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text.rich(
                          TextSpan(
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            children: [
                              const TextSpan(text: 'Uses '),
                              TextSpan(
                                text: '${recipe.usesCount}',
                                style: TextStyle(
                                  color: scheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: ' expiring items'),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}