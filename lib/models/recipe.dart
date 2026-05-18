class Recipe {
  final int? id;
  final String title;
  final String category;
  final String description;
  final String imageUrl;
  final List<String> ingredients;
  final List<String> steps;
  final int cookingTime;
  final int servings;
  final double rating;
  final String difficulty;
  bool isFavorite;

  Recipe({
    this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.ingredients,
    required this.steps,
    required this.cookingTime,
    required this.servings,
    this.rating = 0.0,
    required this.difficulty,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'ingredients': ingredients.join('||'),
      'steps': steps.join('||'),
      'cookingTime': cookingTime,
      'servings': servings,
      'rating': rating,
      'difficulty': difficulty,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'],
      title: map['title'],
      category: map['category'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      ingredients: (map['ingredients'] as String).split('||'),
      steps: (map['steps'] as String).split('||'),
      cookingTime: map['cookingTime'],
      servings: map['servings'],
      rating: map['rating']?.toDouble() ?? 0.0,
      difficulty: map['difficulty'],
      isFavorite: map['isFavorite'] == 1,
    );
  }

  Recipe copyWith({bool? isFavorite}) {
    return Recipe(
      id: id,
      title: title,
      category: category,
      description: description,
      imageUrl: imageUrl,
      ingredients: ingredients,
      steps: steps,
      cookingTime: cookingTime,
      servings: servings,
      rating: rating,
      difficulty: difficulty,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
