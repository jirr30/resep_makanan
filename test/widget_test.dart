import 'package:flutter_test/flutter_test.dart';
import 'package:resep_makanan/models/recipe.dart';

void main() {
  group('Recipe Model', () {
    test('Recipe.toMap dan fromMap simetris', () {
      final recipe = Recipe(
        id: 1,
        title: 'Nasi Goreng',
        category: 'Makanan Utama',
        description: 'Deskripsi nasi goreng',
        imageUrl: 'https://example.com/img.jpg',
        ingredients: ['Nasi', 'Telur', 'Kecap'],
        steps: ['Goreng nasi', 'Tambahkan telur'],
        cookingTime: 20,
        servings: 2,
        rating: 4.5,
        difficulty: 'Mudah',
        isFavorite: false,
      );

      final map = recipe.toMap();
      final fromMap = Recipe.fromMap(map);

      expect(fromMap.title, equals(recipe.title));
      expect(fromMap.ingredients.length, equals(recipe.ingredients.length));
      expect(fromMap.steps.length, equals(recipe.steps.length));
      expect(fromMap.rating, equals(recipe.rating));
    });

    test('copyWith mengubah isFavorite', () {
      final recipe = Recipe(
        title: 'Test',
        category: 'Tes',
        description: 'Desc',
        imageUrl: '',
        ingredients: ['A'],
        steps: ['1'],
        cookingTime: 10,
        servings: 1,
        difficulty: 'Mudah',
        isFavorite: false,
      );

      final favorited = recipe.copyWith(isFavorite: true);
      expect(favorited.isFavorite, isTrue);
      expect(recipe.isFavorite, isFalse);
    });
  });
}
