import 'dart:async';

import 'package:flutter/material.dart';

import '../../../dashboard/presentation/dashboard_summary_controller.dart';
import '../../../quests/data/quest_progress_store.dart';
import '../../../quests/data/streak_service.dart';
import '../../data/fridge_items_controller.dart';
import '../../data/fridge_repository.dart';
import '../../domain/fridge_item.dart';
import '../../domain/recipe_suggestion.dart';

String _normalizeIngredientName(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _formatQuantity(double quantity) {
  return quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(1);
}

/// A recipe's full detail — ingredients, steps, and the "complete recipe"
/// action that subtracts used quantities from the fridge. Self-contained:
/// reads the current fridge stock from [FridgeItemsController] itself, so
/// any page holding a [RecipeSuggestion] (the Fridge page's own list, or
/// the Dashboard's "Cook with what you have" row) can push straight to it.
class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({
    super.key,
    required this.recipe,
    this.fridgeRepository,
  });

  final RecipeSuggestion recipe;
  final FridgeRepository? fridgeRepository;

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  late final FridgeRepository _fridgeRepository;
  late final List<FridgeItem> _usedItems;
  bool _isCompleting = false;
  bool _isComplete = false;
  String? _completionError;
  late int _pax;

  RecipeSuggestion get recipe => widget.recipe;

  int get _basePax => recipe.servings.clamp(1, 8);

  @override
  void initState() {
    super.initState();
    _fridgeRepository =
        widget.fridgeRepository ?? const SupabaseFridgeRepository();
    _usedItems = _ingredientsUsedBy(recipe, FridgeItemsController.items.value);
    _pax = _basePax;
  }

  static List<FridgeItem> _ingredientsUsedBy(
    RecipeSuggestion recipe,
    List<FridgeItem> items,
  ) {
    final usedNames = recipe.ingredientsUsed
        .map((ingredient) => _normalizeIngredientName(ingredient.name))
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    return items.where((item) {
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
    for (final item in _usedItems) {
      final ingredient = _ingredientForItem(item);
      if (ingredient == null || ingredient.quantity <= 0) continue;
      final supported =
          (item.quantity * _basePax / ingredient.quantity).floor();
      if (supported < maximum) maximum = supported;
    }
    return maximum.clamp(1, 8);
  }

  bool get _hasEnoughStock {
    for (final item in _usedItems) {
      final ingredient = _ingredientForItem(item);
      if (ingredient != null &&
          _scaledQuantity(ingredient) > item.quantity + 0.0001) {
        return false;
      }
    }
    return true;
  }

  static const StreakService _streakService = StreakService();

  Future<void> _complete() async {
    if (_isCompleting || _isComplete || _usedItems.isEmpty) return;

    setState(() {
      _isCompleting = true;
      _completionError = null;
    });

    try {
      final scale = _pax / recipe.servings.clamp(1, 100);
      final remainingQuantities = <String, double>{};
      for (final item in _usedItems) {
        final ingredient = _ingredientForItem(item);
        if (ingredient == null) continue;
        final quantityUsed = ingredient.quantity * scale;
        remainingQuantities[item.id] =
            (item.quantity - quantityUsed).clamp(0, item.quantity).toDouble();
      }

      await _fridgeRepository.updateRecipeQuantities(
        remainingQuantities: remainingQuantities,
      );

      FridgeItemsController.items.value =
          FridgeItemsController.items.value.map((item) {
        final remaining = remainingQuantities[item.id];
        if (remaining == null) return item;
        return item.copyWith(
          quantity: remaining,
          isConsumed: remaining <= 0.0001,
        );
      }).toList(growable: false);

      unawaited(QuestProgressStore.recordRecipeCompleted());
      unawaited(QuestProgressStore.recordFridgeActivityToday());

      final now = DateTime.now();
      final urgentItemsCleared = !FridgeItemsController.items.value.any(
        (item) =>
            !item.isConsumed && item.statusAt(now) == FridgeItemStatus.today,
      );
      if (urgentItemsCleared) {
        try {
          await _streakService.bumpDailyStreak();
          DashboardSummaryController.requestRefresh();
        } catch (_) {
          // Recipe completion succeeded; a streak sync failure should not
          // make the completed recipe look like it failed.
        }
      }

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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
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
                              style: theme.textTheme.bodyMedium?.copyWith(
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
                        Text(
                          'Waste-saving tip',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
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
                      : _usedItems.isEmpty
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
                      onPressed: _usedItems.isEmpty ||
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
