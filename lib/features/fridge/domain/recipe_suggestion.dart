class RecipeSuggestion {
  const RecipeSuggestion({
    required this.title,
    required this.summary,
    required this.timeMinutes,
    required this.difficulty,
    required this.servings,
    required this.ingredientsUsed,
    required this.steps,
    required this.wasteSavingTip,
  });

  final String title;
  final String summary;
  final int timeMinutes;
  final String difficulty;
  final int servings;
  final List<RecipeIngredient> ingredientsUsed;
  final List<String> steps;
  final String wasteSavingTip;

  factory RecipeSuggestion.fromJson(Map<String, dynamic> json) {
    return RecipeSuggestion(
      title: json['title'] as String? ?? 'Rescue recipe',
      summary: json['summary'] as String? ?? '',
      timeMinutes: (json['time_minutes'] as num?)?.toInt() ?? 30,
      difficulty: json['difficulty'] as String? ?? 'Easy',
      servings: (json['servings'] as num?)?.toInt() ?? 2,
      ingredientsUsed: _ingredientList(json['ingredients_used']),
      steps: _stringList(json['steps']),
      wasteSavingTip: json['waste_saving_tip'] as String? ?? '',
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  static List<RecipeIngredient> _ingredientList(Object? value) {
    if (value is! List) return const [];
    return value
        .map(RecipeIngredient.fromJson)
        .where((ingredient) => ingredient.name.isNotEmpty)
        .toList(growable: false);
  }
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  final String name;
  final double quantity;
  final String unit;

  factory RecipeIngredient.fromJson(Object? value) {
    if (value is String) {
      return RecipeIngredient(name: value, quantity: 1, unit: 'portion');
    }
    if (value is! Map) {
      return const RecipeIngredient(name: '', quantity: 0, unit: '');
    }

    final json = Map<String, dynamic>.from(value);
    return RecipeIngredient(
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
    );
  }
}
