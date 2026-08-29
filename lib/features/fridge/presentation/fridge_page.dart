import 'package:flutter/material.dart';

import '../data/fridge_repository.dart';
import '../data/openai_recipe_service.dart';
import '../domain/fridge_item.dart';
import '../domain/recipe_suggestion.dart';

String _categoryLabel(String category) {
  if (category.isEmpty) return 'Other';
  return '${category[0].toUpperCase()}${category.substring(1)}';
}

class FridgePage extends StatefulWidget {
  const FridgePage({
    super.key,
    this.recipeService,
    this.fridgeRepository,
  });

  final RecipeSuggestionService? recipeService;
  final FridgeRepository? fridgeRepository;

  @override
  State<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends State<FridgePage> {
  late final RecipeSuggestionService _recipeService;
  late final FridgeRepository _fridgeRepository;
  List<FridgeItem> _items = const [];

  List<RecipeSuggestion> _recipes = const [];
  String? _loadError;
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _recipeService = widget.recipeService ?? const OpenAiRecipeService();
    _fridgeRepository =
        widget.fridgeRepository ?? const SupabaseFridgeRepository();
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final items = await _fridgeRepository.fetchItems();
      if (!mounted) return;

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load your fridge. Check your connection.';
      });
    }
  }

  List<FridgeItem> get _visibleItems {
    final now = DateTime.now();
    final filtered = _items.where((item) {
      final status = item.statusAt(now);
      return status == FridgeItemStatus.today ||
          status == FridgeItemStatus.soon;
    }).toList();

    filtered.sort((a, b) {
      if (a.expiresOn == null) return 1;
      if (b.expiresOn == null) return -1;
      return a.expiresOn!.compareTo(b.expiresOn!);
    });
    return filtered;
  }

  int get _rescueSoonCount {
    return _visibleItems.length;
  }

  int get _recipePriorityCount {
    final now = DateTime.now();
    return _items.where((item) {
      final status = item.statusAt(now);
      return status == FridgeItemStatus.today ||
          status == FridgeItemStatus.soon;
    }).length;
  }

  List<FridgeItem> get _activeIngredients {
    final now = DateTime.now();
    final ingredients = _items.where((item) {
      return !item.isConsumed && item.statusAt(now) != FridgeItemStatus.overdue;
    }).toList();

    ingredients.sort((a, b) {
      if (a.expiresOn == null) return 1;
      if (b.expiresOn == null) return -1;
      return a.expiresOn!.compareTo(b.expiresOn!);
    });
    return ingredients;
  }

  Future<void> _toggleConsumed(FridgeItem item) async {
    final nextValue = !item.isConsumed;
    setState(() {
      _items = _items
          .map(
            (candidate) => candidate.id == item.id
                ? candidate.copyWith(isConsumed: nextValue)
                : candidate,
          )
          .toList(growable: false);
    });

    try {
      await _fridgeRepository.setConsumed(
        id: item.id,
        isConsumed: nextValue,
      );
      if (mounted) {
        _showMessage(
            nextValue ? 'Marked as consumed.' : 'Moved back to fridge.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (candidate) => candidate.id == item.id
                  ? candidate.copyWith(isConsumed: item.isConsumed)
                  : candidate,
            )
            .toList(growable: false);
      });
      _showMessage('Could not update this item. Please try again.');
    }
  }

  Future<void> _generateRecipes() async {
    if (_activeIngredients.isEmpty) {
      _showMessage('No safe, available ingredients were found.');
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final recipes = await _recipeService.generate(
        ingredients: _activeIngredients,
      );
      if (!mounted) return;
      setState(() => _recipes = recipes);
    } on RecipeSuggestionException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage('Something went wrong while creating recipes.');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8F4),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rescue My Fridge',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Eat what you have. Waste less.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadItems,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              sliver: SliverToBoxAdapter(
                child: _AiRecipeLab(
                  priorityCount: _recipePriorityCount,
                  availableCount: _activeIngredients.length,
                  isGenerating: _isGenerating,
                  recipes: _recipes,
                  onGenerate: _generateRecipes,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: _RescueSummary(
                  rescueSoonCount: _rescueSoonCount,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      'Expiring soon',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_visibleItems.length} items',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverPadding(
                padding: EdgeInsets.all(32),
                sliver: SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_loadError != null)
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: _LoadErrorState(
                    message: _loadError!,
                    onRetry: _loadItems,
                  ),
                ),
              )
            else if (_visibleItems.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(child: _EmptyFridgeState()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList.separated(
                  itemCount: _visibleItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _visibleItems[index];
                    return _FridgeItemCard(
                      item: item,
                      onToggleConsumed: () => _toggleConsumed(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RescueSummary extends StatelessWidget {
  const _RescueSummary({
    required this.rescueSoonCount,
  });

  final int rescueSoonCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF155E3B), Color(0xFF278A52)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29155E3B),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rescueSoonCount == 0
                      ? 'Your fridge is on track'
                      : '$rescueSoonCount items need rescuing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These foods are prioritized for your next meal',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FridgeItemCard extends StatelessWidget {
  const _FridgeItemCard({
    required this.item,
    required this.onToggleConsumed,
  });

  final FridgeItem item;
  final VoidCallback onToggleConsumed;

  @override
  Widget build(BuildContext context) {
    final status = item.statusAt(DateTime.now());
    final statusStyle = _statusStyle(status);
    final theme = Theme.of(context);

    return Material(
      color: item.isConsumed ? const Color(0xFFF0F1EE) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusStyle.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _categoryIcon(item.category),
                color: statusStyle.foreground,
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
                      decoration:
                          item.isConsumed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatQuantity(item.quantity)} ${item.unit} · ${_categoryLabel(item.category)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusStyle.background,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    _statusLabel(item, status),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusStyle.foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: onToggleConsumed,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(item.isConsumed ? 'Undo' : 'I ate this'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatQuantity(double quantity) {
    return quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
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
      case 'pantry':
        return Icons.rice_bowl_outlined;
      default:
        return Icons.kitchen_outlined;
    }
  }

  static String _statusLabel(FridgeItem item, FridgeItemStatus status) {
    switch (status) {
      case FridgeItemStatus.overdue:
        final days = item.daysRemainingAt(DateTime.now())!.abs();
        return '$days d overdue';
      case FridgeItemStatus.today:
        return 'Use today';
      case FridgeItemStatus.soon:
        return '${item.daysRemainingAt(DateTime.now())} d left';
      case FridgeItemStatus.fresh:
        return '${item.daysRemainingAt(DateTime.now())} d left';
      case FridgeItemStatus.noExpiry:
        return 'No expiry';
      case FridgeItemStatus.consumed:
        return 'Consumed';
    }
  }

  static _StatusStyle _statusStyle(FridgeItemStatus status) {
    switch (status) {
      case FridgeItemStatus.overdue:
        return const _StatusStyle(Color(0xFFFFE5E2), Color(0xFFB42318));
      case FridgeItemStatus.today:
        return const _StatusStyle(Color(0xFFFFE9D5), Color(0xFFB54708));
      case FridgeItemStatus.soon:
        return const _StatusStyle(Color(0xFFFFF3C6), Color(0xFF8A6100));
      case FridgeItemStatus.fresh:
        return const _StatusStyle(Color(0xFFE2F6E8), Color(0xFF176B3A));
      case FridgeItemStatus.noExpiry:
        return const _StatusStyle(Color(0xFFE7EEF5), Color(0xFF36566F));
      case FridgeItemStatus.consumed:
        return const _StatusStyle(Color(0xFFE6E8E3), Color(0xFF5F665D));
    }
  }
}

class _StatusStyle {
  const _StatusStyle(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

class _AiRecipeLab extends StatelessWidget {
  const _AiRecipeLab({
    required this.priorityCount,
    required this.availableCount,
    required this.isGenerating,
    required this.recipes,
    required this.onGenerate,
  });

  final int priorityCount;
  final int availableCount;
  final bool isGenerating;
  final List<RecipeSuggestion> recipes;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9D0FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D4DD4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Rescue Recipes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$priorityCount expiring soon · $availableCount foods considered',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'AI checks all available food and prioritizes ingredients that expire soon.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isGenerating ? null : onGenerate,
              icon: isGenerating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                isGenerating
                    ? 'Creating rescue recipes…'
                    : 'Recommend rescue recipes',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6D4DD4),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (recipes.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...recipes.map(
              (recipe) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecipeCard(recipe: recipe),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final RecipeSuggestion recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      collapsedShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Text(
        recipe.title,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      subtitle: Text('${recipe.timeMinutes} min · ${recipe.difficulty}'),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(recipe.summary),
        ),
        if (recipe.ingredientsUsed.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: recipe.ingredientsUsed
                  .map((ingredient) => Chip(label: Text(ingredient)))
                  .toList(growable: false),
            ),
          ),
        ],
        if (recipe.steps.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...recipe.steps.indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.$1 + 1}.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.$2)),
                ],
              ),
            ),
          ),
        ],
        if (recipe.wasteSavingTip.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('♻️ ${recipe.wasteSavingTip}'),
          ),
      ],
    );
  }
}

class _EmptyFridgeState extends StatelessWidget {
  const _EmptyFridgeState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          Icon(Icons.kitchen_outlined, size: 44),
          SizedBox(height: 8),
          Text('Nothing needs rescuing soon.'),
        ],
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
