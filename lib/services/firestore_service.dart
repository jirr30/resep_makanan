import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/recipe.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _recipes => _db.collection('community_recipes');

  Future<String> _uploadLocalImage(String localPath, String uid) async {
    final file = File(localPath);
    final ext = localPath.split('.').last;
    final ref = FirebaseStorage.instance
        .ref('community_images/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext');
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  Future<void> publishRecipe(Recipe recipe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String imageUrl = recipe.imageUrl;
    if (recipe.imagePath != null && File(recipe.imagePath!).existsSync()) {
      imageUrl = await _uploadLocalImage(recipe.imagePath!, user.uid);
    }

    await _recipes.add({
      'title': recipe.title,
      'category': recipe.category,
      'description': recipe.description,
      'imageUrl': imageUrl,
      'ingredients': recipe.ingredients,
      'steps': recipe.steps,
      'cookingTime': recipe.cookingTime,
      'servings': recipe.servings,
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
      'averageRating': 0.0,
      'ratingCount': 0,
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

  /// Mengembalikan rating yang sudah diberikan user saat ini, atau 0.0 jika belum.
  Future<double> getUserRating(String recipeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0.0;
    final doc = await _recipes
        .doc(recipeId)
        .collection('ratings')
        .doc(user.uid)
        .get();
    if (!doc.exists) return 0.0;
    return (doc.data()?['rating'] as num?)?.toDouble() ?? 0.0;
  }

  /// Menyimpan / memperbarui rating user, lalu menghitung ulang rata-rata
  /// secara atomik menggunakan Firestore transaction.
  Future<void> rateRecipe(String recipeId, double newRating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Harus login untuk memberi rating');

    final recipeRef = _recipes.doc(recipeId);
    final ratingRef = recipeRef.collection('ratings').doc(user.uid);

    await _db.runTransaction((tx) async {
      final oldRatingDoc = await tx.get(ratingRef);
      final recipeDoc   = await tx.get(recipeRef);

      final recipeData    = recipeDoc.data() as Map<String, dynamic>?;
      final oldRatingData = oldRatingDoc.exists ? oldRatingDoc.data() : null;
      final oldRating = (oldRatingData?['rating'] as num?)?.toDouble();

      final currentCount = (recipeData?['ratingCount'] as num?)?.toInt() ?? 0;
      final currentAvg   = (recipeData?['averageRating'] as num?)?.toDouble() ?? 0.0;

      int newCount;
      double newAvg;

      if (oldRating == null) {
        // Rating pertama dari user ini
        newCount = currentCount + 1;
        newAvg   = currentCount == 0
            ? newRating
            : ((currentAvg * currentCount) + newRating) / newCount;
      } else {
        // User memperbarui rating-nya
        newCount = currentCount > 0 ? currentCount : 1;
        newAvg   = newCount <= 1
            ? newRating
            : ((currentAvg * currentCount) - oldRating + newRating) / newCount;
      }

      tx.set(ratingRef, {
        'rating':    newRating,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(recipeRef, {
        'averageRating': newAvg,
        'ratingCount':   newCount,
      });
    });
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
  final double averageRating;
  final int ratingCount;
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
    required this.averageRating,
    required this.ratingCount,
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
      id:          doc.id,
      title:       d['title']       as String? ?? '',
      category:    d['category']    as String? ?? '',
      description: d['description'] as String? ?? '',
      imageUrl:    d['imageUrl']    as String? ?? '',
      ingredients: List<String>.from(d['ingredients'] ?? []),
      steps:       List<String>.from(d['steps']       ?? []),
      cookingTime: d['cookingTime'] as int? ?? 0,
      servings:    d['servings']    as int? ?? 1,
      // Backward-compatible: baca averageRating, fallback ke rating lama
      averageRating: (d['averageRating'] as num?)?.toDouble()
          ?? (d['rating'] as num?)?.toDouble()
          ?? 0.0,
      ratingCount: d['ratingCount'] as int? ?? 0,
      difficulty:  d['difficulty']  as String? ?? '',
      calories:    d['calories']    as int? ?? 0,
      protein:     (d['protein'] as num?)?.toDouble() ?? 0,
      carbs:       (d['carbs']   as num?)?.toDouble() ?? 0,
      fat:         (d['fat']     as num?)?.toDouble() ?? 0,
      authorId:    d['authorId']    as String? ?? '',
      authorName:  d['authorName']  as String? ?? 'Anonim',
      authorPhoto: d['authorPhoto'] as String? ?? '',
      publishedAt: (d['publishedAt'] as Timestamp?)?.toDate(),
      likes:       d['likes'] as int? ?? 0,
    );
  }

  Recipe toRecipe() => Recipe(
    title:       title,
    category:    category,
    description: description,
    imageUrl:    imageUrl,
    ingredients: ingredients,
    steps:       steps,
    cookingTime: cookingTime,
    servings:    servings,
    rating:      averageRating,
    difficulty:  difficulty,
    isFavorite:  false,
    calories:    calories,
    protein:     protein,
    carbs:       carbs,
    fat:         fat,
  );
}
