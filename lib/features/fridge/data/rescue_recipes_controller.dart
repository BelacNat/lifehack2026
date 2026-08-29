import 'package:flutter/foundation.dart';

import '../domain/fridge_item.dart';
import '../domain/recipe_suggestion.dart';
import 'fridge_repository.dart';
import 'openai_recipe_service.dart';

/// Shared store for the AI-generated Rescue Recipes, so other features
/// (currently the Dashboard) can mirror the same recommendations the Fridge
/// page's Rescue Recipes tab shows, without duplicating the generation
/// pipeline. The Fridge page publishes into [recipes] whenever it
/// regenerates; readers just listen.
class RescueRecipesController {
  RescueRecipesController._();

  static final ValueNotifier<List<RecipeSuggestion>> recipes =
      ValueNotifier<List<RecipeSuggestion>>(const []);

  static final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  static Future<void>? _pending;

  /// Triggers a load the first time it's called (e.g. from the Dashboard,
  /// in case the user hasn't visited the Fridge tab yet this session).
  /// Safe to call repeatedly.
  static Future<void> ensureLoaded({
    FridgeRepository? fridgeRepository,
    RecipeSuggestionService? recipeService,
  }) {
    if (recipes.value.isNotEmpty) return Future.value();
    return _pending ??= _refresh(
      fridgeRepository: fridgeRepository,
      recipeService: recipeService,
    );
  }

  static Future<void> _refresh({
    FridgeRepository? fridgeRepository,
    RecipeSuggestionService? recipeService,
  }) async {
    final repository = fridgeRepository ?? const SupabaseFridgeRepository();
    final service = recipeService ?? const OpenAiRecipeService();

    isLoading.value = true;
    try {
      final items = await repository.fetchItems();
      final now = DateTime.now();
      final activeIngredients = items.where((item) {
        return !item.isConsumed &&
            item.statusAt(now) != FridgeItemStatus.overdue;
      }).toList();

      recipes.value = activeIngredients.isEmpty
          ? const []
          : await service.generate(ingredients: activeIngredients);
    } catch (_) {
      // Leave prior recipes in place; the Fridge page surfaces its own error.
    } finally {
      isLoading.value = false;
      _pending = null;
    }
  }
}
