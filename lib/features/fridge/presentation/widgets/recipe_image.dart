import 'package:flutter/material.dart';

import '../../data/recipe_image_service.dart';

/// Shows a photo matching [recipeTitle], looked up via
/// [RecipeImageService]. Shows [fallback] while loading, on a failed
/// lookup, or if the image itself fails to load.
class RecipeImage extends StatefulWidget {
  const RecipeImage({
    super.key,
    required this.recipeTitle,
    required this.fallback,
  });

  final String recipeTitle;
  final Widget fallback;

  @override
  State<RecipeImage> createState() => _RecipeImageState();
}

class _RecipeImageState extends State<RecipeImage> {
  late Future<String?> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = RecipeImageService.imageUrlFor(widget.recipeTitle);
  }

  @override
  void didUpdateWidget(covariant RecipeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipeTitle != widget.recipeTitle) {
      _urlFuture = RecipeImageService.imageUrlFor(widget.recipeTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _urlFuture,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done || url == null) {
          return widget.fallback;
        }
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => widget.fallback,
        );
      },
    );
  }
}
