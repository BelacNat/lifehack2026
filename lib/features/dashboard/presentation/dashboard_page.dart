import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../fridge/data/fridge_items_controller.dart';
import '../../fridge/data/rescue_recipes_controller.dart';
import '../../fridge/domain/fridge_item.dart';
import '../../fridge/domain/recipe_suggestion.dart';
import '../../fridge/presentation/widgets/recipe_detail_page.dart';
import '../../fridge/presentation/widgets/recipe_image.dart';
import 'dashboard_repository.dart';
import 'dashboard_summary_controller.dart';
import 'widgets/category_breakdown_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _repository = const DashboardRepository();
  late Future<DashboardSummary> _summaryFuture;

  bool _isInsightExpanded = false;

  final List<_ShoppingTip> _extraShoppingTips = const [
    _ShoppingTip(name: 'Rolled oats', action: _TipAction.buy),
    _ShoppingTip(name: 'Bell peppers', action: _TipAction.buy),
    _ShoppingTip(name: 'Extra milk', action: _TipAction.skip),
  ];

  @override
  void initState() {
    super.initState();
    _summaryFuture = _repository.fetchSummary();
    RescueRecipesController.ensureLoaded();
    FridgeItemsController.ensureLoaded();
    DashboardSummaryController.refreshTrigger.addListener(_refreshSummary);
  }

  @override
  void dispose() {
    DashboardSummaryController.refreshTrigger.removeListener(_refreshSummary);
    super.dispose();
  }

  void _refreshSummary() {
    if (!mounted) return;
    setState(() {
      _summaryFuture = _repository.fetchSummary();
    });
  }

  /// Items expiring today or within 3 days, soonest first — matches what
  /// the Fridge page's "Expiring soon" tab shows.
  List<FridgeItem> _soonItems(List<FridgeItem> fridgeItems) {
    final now = DateTime.now();
    final soon = fridgeItems.where((item) {
      if (item.isConsumed) return false;
      final status = item.statusAt(now);
      return status == FridgeItemStatus.today ||
          status == FridgeItemStatus.soon;
    }).toList();

    soon.sort((a, b) {
      final aDays = a.daysRemainingAt(now) ?? 999;
      final bDays = b.daysRemainingAt(now) ?? 999;
      return aDays.compareTo(bDays);
    });
    return soon;
  }

  void _goToFridge() => context.go('/fridge');

  void _goToRescueRecipes() => context.go('/fridge?tab=recipes');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

            return ValueListenableBuilder<List<FridgeItem>>(
              valueListenable: FridgeItemsController.items,
              builder: (context, fridgeItems, _) {
                final soonItems = _soonItems(fridgeItems);
                final expiringToday = soonItems
                    .where((item) =>
                        item.statusAt(DateTime.now()) == FridgeItemStatus.today)
                    .length;
                final activeItems =
                    fridgeItems.where((item) => !item.isConsumed).toList();
                final produceCount = activeItems
                    .where((item) => item.category == 'produce')
                    .length;
                final meatAndDairyCount = activeItems
                    .where((item) =>
                        item.category == 'meat' || item.category == 'dairy')
                    .length;
                final pantryAndOtherCount =
                    activeItems.length - produceCount - meatAndDairyCount;
                final distinctCategoryCount =
                    activeItems.map((item) => item.category).toSet().length;

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
                      child: _ExpiringShelf(items: soonItems, theme: theme),
                    ),
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'Fridge at a glance',
                        actionLabel: '$distinctCategoryCount categories',
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                CategoryBreakdownPage(items: fridgeItems),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _GlanceGrid(
                        theme: theme,
                        produceCount: produceCount,
                        meatAndDairyCount: meatAndDairyCount,
                        pantryAndOtherCount: pantryAndOtherCount,
                        expiringTodayCount: expiringToday,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                    SliverToBoxAdapter(
                      child: _AiInsightBanner(
                        theme: theme,
                        isExpanded: _isInsightExpanded,
                        extraTips: _extraShoppingTips,
                        onToggle: () => setState(
                            () => _isInsightExpanded = !_isInsightExpanded),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'Cook with what you have',
                        actionLabel: 'More recipes',
                        onAction: _goToRescueRecipes,
                        topPadding: 12,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ValueListenableBuilder<List<RecipeSuggestion>>(
                        valueListenable: RescueRecipesController.recipes,
                        builder: (context, recipes, _) {
                          return _RecipeRow(
                            recipes: recipes,
                            theme: theme,
                            onRecipeTap: (recipe) => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    RecipeDetailPage(recipe: recipe),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                );
              },
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

enum _TipAction { buy, skip }

// Urgency coloring shared with the Fridge page: 1 day (or less) left is
// red, 2 days left is yellow, 3+ days left is green.
Color _urgencyColor(FridgeItem item, ColorScheme scheme) {
  final days = item.daysRemainingAt(DateTime.now()) ?? 99;
  if (days <= 1) return scheme.error;
  if (days == 2) return Colors.orange.shade700;
  return Colors.green.shade600;
}

String _urgencyLabel(FridgeItem item) {
  final days = item.daysRemainingAt(DateTime.now()) ?? 0;
  if (days <= 0) return 'Expires today';
  return '$days day${days == 1 ? '' : 's'} left';
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'produce':
      return Icons.eco_outlined;
    case 'meat':
    case 'seafood':
      return Icons.egg_alt_outlined;
    case 'dairy':
    case 'beverage':
      return Icons.local_drink_outlined;
    case 'bakery':
      return Icons.bakery_dining_outlined;
    case 'pantry':
      return Icons.rice_bowl_outlined;
    case 'frozen':
      return Icons.ac_unit_outlined;
    default:
      return Icons.kitchen_outlined;
  }
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
    this.topPadding = 24,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 10),
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

  final List<FridgeItem> items;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Nothing expiring soon — your fridge is on track.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final color = _urgencyColor(item, scheme);
          final quantity = item.quantity == item.quantity.roundToDouble()
              ? item.quantity.toInt().toString()
              : item.quantity.toStringAsFixed(1);

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
                  child: Icon(_categoryIcon(item.category),
                      size: 16, color: color),
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
                  '$quantity ${item.unit}',
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
                    _urgencyLabel(item),
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
  const _GlanceGrid({
    required this.theme,
    required this.produceCount,
    required this.meatAndDairyCount,
    required this.pantryAndOtherCount,
    required this.expiringTodayCount,
  });

  final ThemeData theme;
  final int produceCount;
  final int meatAndDairyCount;
  final int pantryAndOtherCount;
  final int expiringTodayCount;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    final tiles = [
      _GlanceTile(
        icon: Icons.eco_outlined,
        number: produceCount,
        label: 'Fresh produce',
      ),
      _GlanceTile(
        icon: Icons.kitchen_outlined,
        number: meatAndDairyCount,
        label: 'Meat and dairy',
      ),
      _GlanceTile(
        icon: Icons.inventory_2_outlined,
        number: pantryAndOtherCount,
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
            .map(
                (tile) => _GlanceCard(tile: tile, scheme: scheme, theme: theme))
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

  final List<RecipeSuggestion> recipes;
  final ThemeData theme;
  final ValueChanged<RecipeSuggestion> onRecipeTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    if (recipes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Rescue recipes will appear here once your fridge has items to cook with.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recipes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final recipe = recipes[index];

          return InkWell(
            onTap: () => onRecipeTap(recipe),
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
                  SizedBox(
                    height: 96,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RecipeImage(
                          recipeTitle: recipe.title,
                          fallback: Container(
                            color: scheme.surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.restaurant_menu,
                                size: 30,
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
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
                              '${recipe.timeMinutes} min',
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
                          recipe.title,
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
                                text: '${recipe.ingredientsUsed.length}',
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
