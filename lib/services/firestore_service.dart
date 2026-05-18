import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/recipe.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _recipes => _db.collection('community_recipes');

  // ─── Image Upload ────────────────────────────────────────────────────────────

  Future<String> _uploadLocalImage(String localPath, String uid) async {
    final file = File(localPath);
    final ext  = localPath.split('.').last;
    final ref  = FirebaseStorage.instance
        .ref('community_images/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  // ─── Publish ─────────────────────────────────────────────────────────────────

  // Returns Firestore doc ID, or null if user not logged in.
  Future<String?> publishRecipe(Recipe recipe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    String imageUrl = recipe.imageUrl;
    if (recipe.imagePath != null && File(recipe.imagePath!).existsSync()) {
      imageUrl = await _uploadLocalImage(recipe.imagePath!, user.uid);
    }

    final ref = await _recipes.add({
      'title':       recipe.title,
      'category':    recipe.category,
      'description': recipe.description,
      'imageUrl':    imageUrl,
      'ingredients': recipe.ingredients,
      'steps':       recipe.steps,
      'cookingTime': recipe.cookingTime,
      'servings':    recipe.servings,
      'difficulty':  recipe.difficulty,
      'calories':    recipe.calories,
      'protein':     recipe.protein,
      'carbs':       recipe.carbs,
      'fat':         recipe.fat,
      'authorId':    user.uid,
      'authorName':  user.displayName ?? 'Anonim',
      'authorPhoto': user.photoURL ?? '',
      'publishedAt': FieldValue.serverTimestamp(),
      'likes':         0,
      'averageRating': 0.0,
      'ratingCount':   0,
      'commentCount':  0,
    });
    return ref.id;
  }

  // ─── Pagination ───────────────────────────────────────────────────────────────

  static const int pageSize = 15;

  Future<PagedResult> getRecipesPaged({DocumentSnapshot? startAfter}) async {
    var query = _recipes
        .orderBy('publishedAt', descending: true)
        .limit(pageSize);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final snap = await query.get();
    final recipes = snap.docs.map(CommunityRecipe.fromFirestore).toList();
    return PagedResult(
      recipes:  recipes,
      lastDoc:  snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore:  snap.docs.length == pageSize,
    );
  }

  Future<DocumentSnapshot> getLastDocSnapshot(String docId) {
    return _recipes.doc(docId).get();
  }

  // Dipakai untuk pencarian — ambil semua (max 200) dan filter di client
  Future<List<CommunityRecipe>> getAllRecipesForSearch() async {
    final snap = await _recipes
        .orderBy('publishedAt', descending: true)
        .limit(200)
        .get();
    return snap.docs.map(CommunityRecipe.fromFirestore).toList();
  }

  // Top N resep terpopuler berdasarkan likes — untuk dashboard
  Future<List<CommunityRecipe>> getTrendingRecipes({int limit = 5}) async {
    final snap = await _recipes
        .orderBy('likes', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(CommunityRecipe.fromFirestore).toList();
  }

  // Latest N resep komunitas — untuk dashboard
  Future<List<CommunityRecipe>> getLatestCommunityRecipes({int limit = 5}) async {
    final snap = await _recipes
        .orderBy('publishedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(CommunityRecipe.fromFirestore).toList();
  }

  // Total resep di komunitas — untuk stat card
  Future<int> getCommunityRecipeCount() async {
    final snap = await _recipes.count().get();
    return snap.count ?? 0;
  }

  // ─── Like ─────────────────────────────────────────────────────────────────────

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

  // ─── Rating ───────────────────────────────────────────────────────────────────

  Future<double> getUserRating(String recipeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0.0;
    final doc = await _recipes.doc(recipeId).collection('ratings').doc(user.uid).get();
    if (!doc.exists) return 0.0;
    return (doc.data()?['rating'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> rateRecipe(String recipeId, double newRating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Harus login untuk memberi rating');

    final recipeRef = _recipes.doc(recipeId);
    final ratingRef = recipeRef.collection('ratings').doc(user.uid);

    await _db.runTransaction((tx) async {
      final oldRatingDoc = await tx.get(ratingRef);
      final recipeDoc    = await tx.get(recipeRef);

      final recipeData    = recipeDoc.data() as Map<String, dynamic>?;
      final oldRatingData = oldRatingDoc.exists ? oldRatingDoc.data() : null;
      final oldRating     = (oldRatingData?['rating'] as num?)?.toDouble();
      final currentCount  = (recipeData?['ratingCount'] as num?)?.toInt() ?? 0;
      final currentAvg    = (recipeData?['averageRating'] as num?)?.toDouble() ?? 0.0;

      int newCount;
      double newAvg;
      if (oldRating == null) {
        newCount = currentCount + 1;
        newAvg   = currentCount == 0
            ? newRating
            : ((currentAvg * currentCount) + newRating) / newCount;
      } else {
        newCount = currentCount > 0 ? currentCount : 1;
        newAvg   = newCount <= 1
            ? newRating
            : ((currentAvg * currentCount) - oldRating + newRating) / newCount;
      }

      tx.set(ratingRef, {'rating': newRating, 'updatedAt': FieldValue.serverTimestamp()});
      tx.update(recipeRef, {'averageRating': newAvg, 'ratingCount': newCount});
    });
  }

  // ─── Comments ─────────────────────────────────────────────────────────────────

  Stream<List<RecipeComment>> getComments(String recipeId) {
    return _recipes
        .doc(recipeId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(RecipeComment.fromFirestore).toList());
  }

  Future<void> addComment(String recipeId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Harus login untuk berkomentar');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final batch = _db.batch();
    final commentRef = _recipes.doc(recipeId).collection('comments').doc();
    batch.set(commentRef, {
      'userId':    user.uid,
      'userName':  user.displayName ?? 'Anonim',
      'userPhoto': user.photoURL ?? '',
      'text':      trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_recipes.doc(recipeId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> deleteComment(String recipeId, String commentId) async {
    final batch = _db.batch();
    batch.delete(_recipes.doc(recipeId).collection('comments').doc(commentId));
    batch.update(_recipes.doc(recipeId), {
      'commentCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  // ─── My Recipes / Delete ──────────────────────────────────────────────────────

  Future<List<CommunityRecipe>> getMyRecipes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snap = await _recipes
        .where('authorId', isEqualTo: user.uid)
        .orderBy('publishedAt', descending: true)
        .get();
    return snap.docs.map(CommunityRecipe.fromFirestore).toList();
  }

  Future<void> deleteRecipe(String docId) async {
    await _recipes.doc(docId).delete();
  }

  // ─── Profile Stats ────────────────────────────────────────────────────────────

  Future<UserProfileStats> getUserStats(String userId) async {
    final snap = await _recipes.where('authorId', isEqualTo: userId).get();
    final recipes = snap.docs.map(CommunityRecipe.fromFirestore).toList();

    final totalLikes   = recipes.fold<int>(0, (s, r) => s + r.likes);
    final totalRatings = recipes.fold<int>(0, (s, r) => s + r.ratingCount);
    final weightedSum  = recipes.fold<double>(0, (s, r) => s + r.averageRating * r.ratingCount);
    final avgRating    = totalRatings > 0 ? weightedSum / totalRatings : 0.0;

    return UserProfileStats(
      recipeCount:   recipes.length,
      totalLikes:    totalLikes,
      averageRating: avgRating,
      recipes:       recipes,
    );
  }
}

// ─── Data Models ─────────────────────────────────────────────────────────────

class PagedResult {
  final List<CommunityRecipe> recipes;
  final DocumentSnapshot?     lastDoc;
  final bool                  hasMore;
  const PagedResult({required this.recipes, required this.lastDoc, required this.hasMore});
}

class UserProfileStats {
  final int                  recipeCount;
  final int                  totalLikes;
  final double               averageRating;
  final List<CommunityRecipe> recipes;
  const UserProfileStats({
    required this.recipeCount,
    required this.totalLikes,
    required this.averageRating,
    required this.recipes,
  });
}

class RecipeComment {
  final String    id;
  final String    userId;
  final String    userName;
  final String    userPhoto;
  final String    text;
  final DateTime? createdAt;

  const RecipeComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.text,
    this.createdAt,
  });

  factory RecipeComment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RecipeComment(
      id:        doc.id,
      userId:    d['userId']    as String? ?? '',
      userName:  d['userName']  as String? ?? 'Anonim',
      userPhoto: d['userPhoto'] as String? ?? '',
      text:      d['text']      as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class CommunityRecipe {
  final String         id;
  final String         title;
  final String         category;
  final String         description;
  final String         imageUrl;
  final List<String>   ingredients;
  final List<String>   steps;
  final int            cookingTime;
  final int            servings;
  final double         averageRating;
  final int            ratingCount;
  final String         difficulty;
  final int            calories;
  final double         protein;
  final double         carbs;
  final double         fat;
  final String         authorId;
  final String         authorName;
  final String         authorPhoto;
  final DateTime?      publishedAt;
  final int            likes;
  final int            commentCount;

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
    this.commentCount = 0,
  });

  factory CommunityRecipe.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommunityRecipe(
      id:           doc.id,
      title:        d['title']       as String? ?? '',
      category:     d['category']    as String? ?? '',
      description:  d['description'] as String? ?? '',
      imageUrl:     d['imageUrl']    as String? ?? '',
      ingredients:  List<String>.from(d['ingredients'] ?? []),
      steps:        List<String>.from(d['steps']       ?? []),
      cookingTime:  d['cookingTime'] as int? ?? 0,
      servings:     d['servings']    as int? ?? 1,
      averageRating: (d['averageRating'] as num?)?.toDouble()
          ?? (d['rating'] as num?)?.toDouble()
          ?? 0.0,
      ratingCount:  d['ratingCount']  as int? ?? 0,
      difficulty:   d['difficulty']   as String? ?? '',
      calories:     d['calories']     as int? ?? 0,
      protein:      (d['protein'] as num?)?.toDouble() ?? 0,
      carbs:        (d['carbs']   as num?)?.toDouble() ?? 0,
      fat:          (d['fat']     as num?)?.toDouble() ?? 0,
      authorId:     d['authorId']     as String? ?? '',
      authorName:   d['authorName']   as String? ?? 'Anonim',
      authorPhoto:  d['authorPhoto']  as String? ?? '',
      publishedAt:  (d['publishedAt'] as Timestamp?)?.toDate(),
      likes:        d['likes']        as int? ?? 0,
      commentCount: d['commentCount'] as int? ?? 0,
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
