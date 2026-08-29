import 'package:flutter/material.dart';

import '../../../fridge/domain/fridge_item.dart';

/// Every category with at least one item at home, not just the 4 tiles
/// shown on the Dashboard's glance grid.
class CategoryBreakdownPage extends StatelessWidget {
  const CategoryBreakdownPage({super.key, required this.items});

  final List<FridgeItem> items;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final item in items) {
      if (item.isConsumed) continue;
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    final categories = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return Scaffold(
      appBar: AppBar(title: const Text('Fridge categories')),
      body: categories.isEmpty
          ? const Center(child: Text('Nothing in your fridge yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final category = categories[index];
                final categoryItems = items
                    .where(
                        (item) => !item.isConsumed && item.category == category)
                    .toList();
                return _CategoryRow(
                  category: category,
                  count: counts[category]!,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => _CategoryItemsPage(
                        category: category,
                        items: categoryItems,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.count,
    required this.onTap,
  });

  final String category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_categoryIcon(category), color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _categoryLabel(category),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$count',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  static String _categoryLabel(String category) {
    if (category.isEmpty) return 'Other';
    return '${category[0].toUpperCase()}${category.substring(1)}';
  }

  static IconData _categoryIcon(String category) {
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
      case 'condiment':
        return Icons.liquor_outlined;
      case 'frozen':
        return Icons.ac_unit_outlined;
      default:
        return Icons.kitchen_outlined;
    }
  }
}

class _CategoryItemsPage extends StatelessWidget {
  const _CategoryItemsPage({required this.category, required this.items});

  final String category;
  final List<FridgeItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_CategoryRow._categoryLabel(category))),
      body: items.isEmpty
          ? const Center(child: Text('No items in this category.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final quantity = item.quantity == item.quantity.roundToDouble()
                    ? item.quantity.toInt().toString()
                    : item.quantity.toStringAsFixed(1);

                return Material(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _CategoryRow._categoryIcon(category),
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$quantity ${item.unit}'
                                '${item.expiresOn == null ? '' : ' · expires ${_formatDate(item.expiresOn!)}'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
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

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
