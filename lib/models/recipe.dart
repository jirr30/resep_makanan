class Recipe {
  final int? id;
  final String? firestoreId; // non-null setelah dipublikasikan ke komunitas
  final String title;
  final String category;
  final String description;
  final String imageUrl;
  final String? imagePath; // gambar lokal dari galeri
  final List<String> ingredients;
  final List<String> steps;
  final int cookingTime;
  final int servings;
  final double rating;     // rating sample bawaan
  final double userRating; // rating dari pengguna
  final String difficulty;
  bool isFavorite;
  // nutrisi
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  Recipe({
    this.id,
    this.firestoreId,
    required this.title,
    required this.category,
    required this.description,
    required this.imageUrl,
    this.imagePath,
    required this.ingredients,
    required this.steps,
    required this.cookingTime,
    required this.servings,
    this.rating = 0.0,
    this.userRating = 0.0,
    required this.difficulty,
    this.isFavorite = false,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'title': title,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'ingredients': ingredients.join('||'),
      'steps': steps.join('||'),
      'cookingTime': cookingTime,
      'servings': servings,
      'rating': rating,
      'userRating': userRating,
      'difficulty': difficulty,
      'isFavorite': isFavorite ? 1 : 0,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'],
      firestoreId: map['firestoreId'] as String?,
      title: map['title'],
      category: map['category'],
      description: map['description'],
      imageUrl: map['imageUrl'] ?? '',
      imagePath: map['imagePath'],
      ingredients: (map['ingredients'] as String).split('||'),
      steps: (map['steps'] as String).split('||'),
      cookingTime: map['cookingTime'],
      servings: map['servings'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      userRating: (map['userRating'] ?? 0.0).toDouble(),
      difficulty: map['difficulty'],
      isFavorite: map['isFavorite'] == 1,
      calories: map['calories'] ?? 0,
      protein: (map['protein'] ?? 0.0).toDouble(),
      carbs: (map['carbs'] ?? 0.0).toDouble(),
      fat: (map['fat'] ?? 0.0).toDouble(),
    );
  }

  Recipe copyWith({
    String? firestoreId,
    bool? isFavorite,
    double? userRating,
    String? imagePath,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return Recipe(
      id: id,
      firestoreId: firestoreId ?? this.firestoreId,
      title: title,
      category: category,
      description: description,
      imageUrl: imageUrl,
      imagePath: imagePath ?? this.imagePath,
      ingredients: ingredients,
      steps: steps,
      cookingTime: cookingTime,
      servings: servings,
      rating: rating,
      userRating: userRating ?? this.userRating,
      difficulty: difficulty,
      isFavorite: isFavorite ?? this.isFavorite,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
    );
  }
}
