import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/fridge_item.dart';
import '../domain/recipe_suggestion.dart';
import 'fridge_repository.dart';
import 'openai_recipe_service.dart';

/// Shared store for AI-generated Rescue Recipes so the Dashboard can mirror
/// the Fridge page's recommendations.
///
/// Recipes are cached per signed-in Supabase user. A result generated for one
/// account is never published after the user has switched accounts.
class RescueRecipesController {
  RescueRecipesController._();

  static final ValueNotifier<List<RecipeSuggestion>> recipes =
      ValueNotifier<List<RecipeSuggestion>>(const []);

  static final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  static String? _loadedUserId;
  static String? _pendingUserId;
  static Future<void>? _pending;

  static String? get _currentUserId {
    try {
      return supabase.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static void _syncUserScope() {
    final userId = _currentUserId;
    if (_loadedUserId == userId) return;

    _loadedUserId = userId;
    recipes.value = const [];
    isLoading.value = false;
    _pending = null;
    _pendingUserId = null;
  }

  /// Triggers generation the first time it's called for the current user.
  static Future<void> ensureLoaded({
    FridgeRepository? fridgeRepository,
    RecipeSuggestionService? recipeService,
  }) {
    _syncUserScope();
    if (recipes.value.isNotEmpty) return Future.value();

    final userId = _currentUserId;
    if (_pending != null && _pendingUserId == userId) return _pending!;

    _pendingUserId = userId;
    _pending = _refresh(
      userId: userId,
      fridgeRepository: fridgeRepository,
      recipeService: recipeService,
    );
    return _pending!;
  }

  static Future<void> _refresh({
    required String? userId,
    FridgeRepository? fridgeRepository,
    RecipeSuggestionService? recipeService,
  }) async {
    final repository = fridgeRepository ?? const SupabaseFridgeRepository();
    final service = recipeService ?? const OpenAiRecipeService();

    if (_currentUserId == userId) isLoading.value = true;
    try {
      final items = await repository.fetchItems();
      final now = DateTime.now();
      final activeIngredients = items.where((item) {
        return !item.isConsumed &&
            item.statusAt(now) != FridgeItemStatus.overdue;
      }).toList();

      final generated = activeIngredients.isEmpty
          ? const <RecipeSuggestion>[]
          : await service.generate(ingredients: activeIngredients);

      if (_currentUserId == userId) {
        recipes.value = generated;
      }
    } catch (_) {
      if (_currentUserId == userId) {
        recipes.value = const [];
      }
      // The Fridge page surfaces its own generation/load error.
    } finally {
      if (_currentUserId == userId) isLoading.value = false;
      if (_pendingUserId == userId) {
        _pending = null;
        _pendingUserId = null;
      }
    }
  }
}
