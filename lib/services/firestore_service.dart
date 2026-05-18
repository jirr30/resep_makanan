import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _recipes => _db.collection('community_recipes');

  Future<void> publishRecipe(Recipe recipe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _recipes.add({
      'title': recipe.title,
      'category': recipe.category,
      'description': recipe.description,
      'imageUrl': recipe.imageUrl,
      'ingredients': recipe.ingredients,
      'steps': recipe.steps,
      'cookingTime': recipe.cookingTime,
      'servings': recipe.servings,
      'rating': recipe.rating,
      'difficulty': recipe.difficulty,
      'calories': recipe.calories,
      'protein': recipe.protein,
      'carbs': recipe.carbs,
      'fat': recipe.fat,
      'authorId': user.uid,
      'authorName': user.displayName ?? 'Anonim',
      'authorPhoto': user.photoURL ?? '',
      'publishedAt': FieldValue.serverTimestamp(),
      'likes': 0,
    });
  }

  Stream<List<CommunityRecipe>> getCommunityRecipes() {
    return _recipes
        .orderBy('publishedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CommunityRecipe.fromFirestore(d))
            .toList());
  }

  Future<void> toggleLike(String docId, bool liked) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final likesRef = _recipes.doc(docId).collection('likes').doc(user.uid);
    if (liked) {
      await likesRef.set({'likedAt': FieldValue.serverTimestamp()});
      await _recipes.doc(docId).update({'likes': FieldValue.increment(1)});
    } else {
      await likesRef.delete();
      await _recipes.doc(docId).update({'likes': FieldValue.increment(-1)});
    }
  }

  Future<bool> isLiked(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await _recipes.doc(docId).collection('likes').doc(user.uid).get();
    return doc.exists;
  }

  Future<List<CommunityRecipe>> getMyRecipes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snap = await _recipes
        .where('authorId', isEqualTo: user.uid)
        .orderBy('publishedAt', descending: true)
        .get();
    return snap.docs.map((d) => CommunityRecipe.fromFirestore(d)).toList();
  }

  Future<void> deleteRecipe(String docId) async {
    await _recipes.doc(docId).delete();
  }
}

class CommunityRecipe {
  final String id;
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
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String authorId;
  final String authorName;
  final String authorPhoto;
  final DateTime? publishedAt;
  final int likes;

  const CommunityRecipe({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.ingredients,
    required this.steps,
    required this.cookingTime,
    required this.servings,
    required this.rating,
    required this.difficulty,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.authorId,
    required this.authorName,
    required this.authorPhoto,
    this.publishedAt,
    required this.likes,
  });

  factory CommunityRecipe.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommunityRecipe(
      id: doc.id,
      title: d['title'] as String? ?? '',
      category: d['category'] as String? ?? '',
      description: d['description'] as String? ?? '',
      imageUrl: d['imageUrl'] as String? ?? '',
      ingredients: List<String>.from(d['ingredients'] ?? []),
      steps: List<String>.from(d['steps'] ?? []),
      cookingTime: d['cookingTime'] as int? ?? 0,
      servings: d['servings'] as int? ?? 1,
      rating: (d['rating'] as num?)?.toDouble() ?? 0,
      difficulty: d['difficulty'] as String? ?? '',
      calories: d['calories'] as int? ?? 0,
      protein: (d['protein'] as num?)?.toDouble() ?? 0,
      carbs: (d['carbs'] as num?)?.toDouble() ?? 0,
      fat: (d['fat'] as num?)?.toDouble() ?? 0,
      authorId: d['authorId'] as String? ?? '',
      authorName: d['authorName'] as String? ?? 'Anonim',
      authorPhoto: d['authorPhoto'] as String? ?? '',
      publishedAt: (d['publishedAt'] as Timestamp?)?.toDate(),
      likes: d['likes'] as int? ?? 0,
    );
  }

  Recipe toRecipe() => Recipe(
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
    isFavorite: false,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
  );
}
