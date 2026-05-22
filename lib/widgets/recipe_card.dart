import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../utils/app_theme.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: _buildImage(recipe, context),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Icon(
                        recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: recipe.isFavorite ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      recipe.category,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textOn(context)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.description,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSubOn(context)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _InfoChip(icon: Icons.timer, label: '${recipe.cookingTime} mnt'),
                      const SizedBox(width: 8),
                      _InfoChip(icon: Icons.people, label: '${recipe.servings} porsi'),
                      const SizedBox(width: 8),
                      _InfoChip(icon: Icons.bar_chart, label: recipe.difficulty),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 2),
                          Text(
                            recipe.rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
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

Widget _buildImage(Recipe recipe, BuildContext context) {
  Widget placeholder() => SizedBox(
    height: 180,
    width: double.infinity,
    child: ColoredBox(
      color: AppTheme.surfaceOn(context),
      child: const Icon(Icons.restaurant, size: 60, color: AppTheme.primary),
    ),
  );

  if (recipe.imagePath != null && File(recipe.imagePath!).existsSync()) {
    return Image.file(
      File(recipe.imagePath!),
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder(),
    );
  }
  if (recipe.imageUrl.isNotEmpty) {
    return Image.network(
      recipe.imageUrl,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder(),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: 180,
          child: ColoredBox(
            color: AppTheme.surfaceOn(context),
            child: const Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }
  return placeholder();
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOn(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderOn(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSubOn(context)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSubOn(context))),
        ],
      ),
    );
  }
}
