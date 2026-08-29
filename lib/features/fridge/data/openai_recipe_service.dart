import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/fridge_item.dart';
import '../domain/recipe_suggestion.dart';

abstract class RecipeSuggestionService {
  Future<List<RecipeSuggestion>> generate({
    required List<FridgeItem> ingredients,
  });
}

/// Calls a server-side Supabase Edge Function that talks to the OpenAI API.
/// The OpenAI key must live in the function's secrets, never in this app.
class OpenAiRecipeService implements RecipeSuggestionService {
  const OpenAiRecipeService({FunctionsClient? functions})
      : _functions = functions;

  static const functionName = 'openai-recipe-suggestions';

  final FunctionsClient? _functions;

  @override
  Future<List<RecipeSuggestion>> generate({
    required List<FridgeItem> ingredients,
  }) async {
    if (ingredients.isEmpty) {
      throw const RecipeSuggestionException(
        'Add at least one available ingredient.',
      );
    }

    try {
      final now = DateTime.now();
      final response = await (_functions ?? supabase.functions).invoke(
        functionName,
        body: {
          'ingredients': ingredients
              .map((item) => item.toRecipeIngredient(now))
              .toList(growable: false),
          'recipe_count': 3,
        },
      );

      final data = response.data;
      final rawRecipes = data is Map<String, dynamic>
          ? data['recipes']
          : data is Map
              ? data['recipes']
              : null;

      if (rawRecipes is! List) {
        throw const RecipeSuggestionException(
          'The recipe service returned an unexpected response.',
        );
      }

      final recipes = rawRecipes
          .whereType<Map>()
          .map(
            (recipe) => RecipeSuggestion.fromJson(
              Map<String, dynamic>.from(recipe),
            ),
          )
          .toList(growable: false);

      if (recipes.isEmpty) {
        throw const RecipeSuggestionException(
          'No recipes were returned. Try adding more ingredients.',
        );
      }

      return recipes;
    } on RecipeSuggestionException {
      rethrow;
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['message'] : null;
      throw RecipeSuggestionException(
        message is String && message.isNotEmpty
            ? message
            : 'The AI recipe service is not available yet.',
      );
    } catch (_) {
      throw const RecipeSuggestionException(
        'Could not reach the AI recipe service. Please try again.',
      );
    }
  }
}

class RecipeSuggestionException implements Exception {
  const RecipeSuggestionException(this.message);

  final String message;

  @override
  String toString() => message;
}
