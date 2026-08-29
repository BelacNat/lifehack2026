import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up a real photo matching a recipe's name via Wikipedia's keyless
/// public search API. Searching articles (rather than raw Commons files)
/// means the result is a curated, topically-correct lead image — e.g.
/// "Creamy Orange Juice Smoothie" resolves to the "Orange Julius" article's
/// photo, not an unrelated document or illustration.
class RecipeImageService {
  const RecipeImageService._();

  static final Map<String, String?> _cache = {};

  static Future<String?> imageUrlFor(String recipeTitle) async {
    final query = recipeTitle.trim();
    if (query.isEmpty) return null;
    if (_cache.containsKey(query)) return _cache[query];

    try {
      final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': query,
        'gsrlimit': '1',
        'prop': 'pageimages',
        'piprop': 'thumbnail',
        'pithumbsize': '400',
        'format': 'json',
        'origin': '*',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        _cache[query] = null;
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final pages = (decoded['query'] as Map<String, dynamic>?)?['pages']
          as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) {
        _cache[query] = null;
        return null;
      }

      final firstPage = pages.values.first as Map<String, dynamic>;
      final thumbnail = firstPage['thumbnail'] as Map<String, dynamic>?;
      final url = thumbnail?['source'] as String?;
      _cache[query] = url;
      return url;
    } catch (_) {
      _cache[query] = null;
      return null;
    }
  }
}
