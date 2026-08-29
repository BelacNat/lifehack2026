import 'package:flutter/material.dart';

import '../data/fridge_repository.dart';
import '../data/openai_recipe_service.dart';
import '../domain/fridge_item.dart';
import '../domain/recipe_suggestion.dart';

String _categoryLabel(String category) {
  if (category.isEmpty) return 'Other';
  return '${category[0].toUpperCase()}${category.substring(1)}';
}

String _normalizeIngredientName(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _formatQuantity(double quantity) {
  return quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(1);
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
  String? _recipeError;
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
      await _generateRecipes();
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
      setState(() {
        _recipeError = 'No safe, available ingredients were found.';
        _recipes = const [];
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _recipeError = null;
    });
    try {
      final recipes = await _recipeService.generate(
        ingredients: _activeIngredients,
      );
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _recipeError = null;
      });
    } on RecipeSuggestionException catch (error) {
      if (mounted) setState(() => _recipeError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _recipeError = 'Something went wrong while creating recipes.';
        });
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  List<FridgeItem> _ingredientsUsedBy(RecipeSuggestion recipe) {
    final usedNames = recipe.ingredientsUsed
        .map((ingredient) => _normalizeIngredientName(ingredient.name))
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    return _items.where((item) {
      if (item.isConsumed || item.quantity <= 0) return false;
      final itemName = _normalizeIngredientName(item.name);
      return usedNames.any(
        (usedName) =>
            usedName == itemName ||
            usedName.contains(itemName) ||
            itemName.contains(usedName),
      );
    }).toList(growable: false);
  }

  RecipeIngredient? _recipeIngredientForItem(
    RecipeSuggestion recipe,
    FridgeItem item,
  ) {
    final itemName = _normalizeIngredientName(item.name);
    for (final ingredient in recipe.ingredientsUsed) {
      final ingredientName = _normalizeIngredientName(ingredient.name);
      if (ingredientName == itemName ||
          ingredientName.contains(itemName) ||
          itemName.contains(ingredientName)) {
        return ingredient;
      }
    }
    return null;
  }

  Future<void> _completeRecipe(
    RecipeSuggestion recipe,
    List<FridgeItem> usedItems,
    int pax,
  ) async {
    final scale = pax / recipe.servings.clamp(1, 100);
    final remainingQuantities = <String, double>{};
    for (final item in usedItems) {
      final ingredient = _recipeIngredientForItem(recipe, item);
      if (ingredient == null) continue;
      final quantityUsed = ingredient.quantity * scale;
      remainingQuantities[item.id] =
          (item.quantity - quantityUsed).clamp(0, item.quantity).toDouble();
    }

    await _fridgeRepository.updateRecipeQuantities(
      remainingQuantities: remainingQuantities,
    );
    if (!mounted) return;

    setState(() {
      _items = _items.map(
        (item) {
          final remaining = remainingQuantities[item.id];
          if (remaining == null) return item;
          return item.copyWith(
            quantity: remaining,
            isConsumed: remaining <= 0.0001,
          );
        },
      ).toList(growable: false);
    });
  }

  void _openRecipe(RecipeSuggestion recipe) {
    final usedItems = _ingredientsUsedBy(recipe);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _RecipeDetailPage(
          recipe: recipe,
          usedItems: usedItems,
          onComplete: (pax) => _completeRecipe(recipe, usedItems, pax),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.schedule_rounded),
                text: 'Expiring soon',
              ),
              Tab(
                icon: Icon(Icons.auto_awesome_rounded),
                text: 'Rescue recipes',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _loadItems,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
            RefreshIndicator(
              onRefresh: _generateRecipes,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _AiRecipeLab(
                    priorityCount: _recipePriorityCount,
                    availableCount: _activeIngredients.length,
                    isGenerating: _isGenerating,
                    recipes: _recipes,
                    errorMessage: _recipeError,
                    onGenerate: _generateRecipes,
                    onSelectRecipe: _openRecipe,
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
    required this.errorMessage,
    required this.onGenerate,
    required this.onSelectRecipe,
  });

  final int priorityCount;
  final int availableCount;
  final bool isGenerating;
  final List<RecipeSuggestion> recipes;
  final String? errorMessage;
  final VoidCallback onGenerate;
  final ValueChanged<RecipeSuggestion> onSelectRecipe;

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
                      'Rescue Recipes',
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
              if (recipes.isNotEmpty)
                IconButton(
                  tooltip: 'Refresh recipes',
                  onPressed: isGenerating ? null : onGenerate,
                  icon: isGenerating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
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
          if (isGenerating && recipes.isEmpty) ...[
            const SizedBox(height: 24),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Preparing your rescue recipes…'),
                ],
              ),
            ),
          ],
          if (errorMessage != null && recipes.isEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onGenerate,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ],
          if (recipes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Recommended for you',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...recipes.map(
              (recipe) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecipeCard(
                  recipe: recipe,
                  onSelect: () => onSelectRecipe(recipe),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.onSelect});

  final RecipeSuggestion recipe;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Color(0xFF6D4DD4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${recipe.timeMinutes} min · ${recipe.difficulty} · ${recipe.servings} pax',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(recipe.summary),
          if (recipe.ingredientsUsed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: recipe.ingredientsUsed
                  .take(3)
                  .map((ingredient) => Chip(label: Text(ingredient.name)))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onSelect,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Select recipe'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeDetailPage extends StatefulWidget {
  const _RecipeDetailPage({
    required this.recipe,
    required this.usedItems,
    required this.onComplete,
  });

  final RecipeSuggestion recipe;
  final List<FridgeItem> usedItems;
  final Future<void> Function(int pax) onComplete;

  @override
  State<_RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<_RecipeDetailPage> {
  bool _isCompleting = false;
  bool _isComplete = false;
  String? _completionError;
  late int _pax;

  RecipeSuggestion get recipe => widget.recipe;

  int get _basePax => recipe.servings.clamp(1, 8);

  @override
  void initState() {
    super.initState();
    _pax = _basePax;
  }

  RecipeIngredient? _ingredientForItem(FridgeItem item) {
    final itemName = _normalizeIngredientName(item.name);
    for (final ingredient in recipe.ingredientsUsed) {
      final ingredientName = _normalizeIngredientName(ingredient.name);
      if (ingredientName == itemName ||
          ingredientName.contains(itemName) ||
          itemName.contains(ingredientName)) {
        return ingredient;
      }
    }
    return null;
  }

  double _scaledQuantity(RecipeIngredient ingredient) {
    return ingredient.quantity * (_pax / _basePax);
  }

  int get _maxPax {
    var maximum = 8;
    for (final item in widget.usedItems) {
      final ingredient = _ingredientForItem(item);
      if (ingredient == null || ingredient.quantity <= 0) continue;
      final supported =
          (item.quantity * _basePax / ingredient.quantity).floor();
      if (supported < maximum) maximum = supported;
    }
    return maximum.clamp(1, 8);
  }

  bool get _hasEnoughStock {
    for (final item in widget.usedItems) {
      final ingredient = _ingredientForItem(item);
      if (ingredient != null &&
          _scaledQuantity(ingredient) > item.quantity + 0.0001) {
        return false;
      }
    }
    return true;
  }

  Future<void> _complete() async {
    if (_isCompleting || _isComplete || widget.usedItems.isEmpty) return;

    setState(() {
      _isCompleting = true;
      _completionError = null;
    });

    try {
      await widget.onComplete(_pax);
      if (!mounted) return;
      setState(() => _isComplete = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _completionError = 'Could not update your fridge. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8F4),
        title: const Text('Rescue recipe'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5F43C8), Color(0xFF8265E8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 14),
                Text(
                  recipe.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  recipe.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _RecipeMeta(
                      icon: Icons.schedule_rounded,
                      label: '${recipe.timeMinutes} min',
                    ),
                    const SizedBox(width: 10),
                    _RecipeMeta(
                      icon: Icons.signal_cellular_alt_rounded,
                      label: recipe.difficulty,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (recipe.ingredientsUsed.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ingredients',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFFDADDD7)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Fewer pax',
                        onPressed: _isComplete || _pax <= 1
                            ? null
                            : () => setState(() => _pax--),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Text(
                        '$_pax pax',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        tooltip: 'More pax',
                        onPressed: _isComplete || _pax >= _maxPax
                            ? null
                            : () => setState(() => _pax++),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _pax >= _maxPax && _maxPax < 8
                  ? 'Maximum based on your tracked fridge stock'
                  : 'Adjust the quantities for the number of people cooking',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: recipe.ingredientsUsed
                    .map(
                      (ingredient) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.eco_outlined,
                              size: 19,
                              color: Color(0xFF278A52),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(ingredient.name)),
                            Text(
                              '${_formatQuantity(_scaledQuantity(ingredient))} ${ingredient.unit}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          if (recipe.steps.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'How to make it',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...recipe.steps.indexed.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: const Color(0xFF6D4DD4),
                        foregroundColor: Colors.white,
                        child: Text('${entry.$1 + 1}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(entry.$2)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (recipe.wasteSavingTip.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5F6E9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.recycling_rounded, color: Color(0xFF176B3A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Waste-saving tip',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(recipe.wasteSavingTip),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _isComplete ? const Color(0xFFE5F6E9) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isComplete
                    ? const Color(0xFFA9DDB6)
                    : const Color(0xFFE1E4DE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isComplete
                          ? Icons.check_circle_rounded
                          : Icons.inventory_2_outlined,
                      color: _isComplete
                          ? const Color(0xFF176B3A)
                          : const Color(0xFF6D4DD4),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isComplete
                            ? 'Recipe completed'
                            : 'Complete this recipe',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _isComplete
                      ? 'The quantities for $_pax pax were removed from your fridge.'
                      : widget.usedItems.isEmpty
                          ? 'No matching fridge quantities were found for this recipe.'
                          : 'This subtracts the scaled ingredient quantities shown above from your fridge.',
                ),
                if (!_hasEnoughStock && !_isComplete) ...[
                  const SizedBox(height: 10),
                  Text(
                    'There is not enough tracked stock for $_pax pax. Choose fewer pax.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                if (_completionError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _completionError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                if (!_isComplete) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.usedItems.isEmpty ||
                              !_hasEnoughStock ||
                              _isCompleting
                          ? null
                          : _complete,
                      icon: _isCompleting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _isCompleting
                            ? 'Updating your fridge…'
                            : 'Complete recipe',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeMeta extends StatelessWidget {
  const _RecipeMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
