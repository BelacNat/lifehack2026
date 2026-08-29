class RecipeSuggestion {
  const RecipeSuggestion({
    required this.title,
    required this.summary,
    required this.timeMinutes,
    required this.difficulty,
    required this.ingredientsUsed,
    required this.steps,
    required this.wasteSavingTip,
  });

  final String title;
  final String summary;
  final int timeMinutes;
  final String difficulty;
  final List<String> ingredientsUsed;
  final List<String> steps;
  final String wasteSavingTip;

  factory RecipeSuggestion.fromJson(Map<String, dynamic> json) {
    return RecipeSuggestion(
      title: json['title'] as String? ?? 'Rescue recipe',
      summary: json['summary'] as String? ?? '',
      timeMinutes: (json['time_minutes'] as num?)?.toInt() ?? 30,
      difficulty: json['difficulty'] as String? ?? 'Easy',
      ingredientsUsed: _stringList(json['ingredients_used']),
      steps: _stringList(json['steps']),
      wasteSavingTip: json['waste_saving_tip'] as String? ?? '',
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }
}
