import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/recipe.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _recipes => _db.collection('community_recipes');
  CollectionReference get _users   => _db.collection('users');
  CollectionReference get _follows => _db.collection('follows');

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
      'viewCount':     0,
    });
    return ref.id;
  }

  // ─── Pagination ───────────────────────────────────────────────────────────────

  static const int pageSize = 15;

  Future<PagedResult> getRecipesPaged({
    DocumentSnapshot? startAfter,
    String? category,
  }) async {
    Query q = (category != null && category.isNotEmpty)
        ? _recipes
            .where('category', isEqualTo: category)
            .orderBy('publishedAt', descending: true)
        : _recipes.orderBy('publishedAt', descending: true);
    q = q.limit(pageSize);
    if (startAfter != null) q = q.startAfterDocument(startAfter);

    final snap = await q.get();
    final recipes = snap.docs.map(CommunityRecipe.fromFirestore).toList();
    return PagedResult(
      recipes: recipes,
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == pageSize,
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

  // Aktivitas komunitas — untuk panel notifikasi
  Future<List<AppNotification>> getActivityNotifications({int limit = 10}) async {
    final snap = await _recipes
        .orderBy('publishedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((doc) {
      final recipe = CommunityRecipe.fromFirestore(doc);
      return AppNotification(
        id: doc.id,
        title: '${recipe.authorName} membagikan resep baru',
        body: recipe.title,
        time: recipe.publishedAt,
        imageUrl: recipe.imageUrl,
        recipe: recipe,
      );
    }).toList();
  }

  // Total resep di komunitas — untuk stat card
  Future<int> getCommunityRecipeCount() async {
    final snap = await _recipes.count().get();
    return snap.count ?? 0;
  }

  // ─── Like ─────────────────────────────────────────────────────────────────────

  // ─── View Count ───────────────────────────────────────────────────────────────

  // Dedup per sesi: satu resep hanya dihitung sekali selama app berjalan
  static final _viewedThisSession = <String>{};

  Future<void> incrementViewCount(String docId) async {
    if (_viewedThisSession.contains(docId)) return;
    _viewedThisSession.add(docId);
    await _recipes.doc(docId).update({'viewCount': FieldValue.increment(1)});
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
    try {
      // Butuh composite index: authorId ASC + publishedAt DESC
      final snap = await _recipes
          .where('authorId', isEqualTo: user.uid)
          .orderBy('publishedAt', descending: true)
          .get();
      return snap.docs.map(CommunityRecipe.fromFirestore).toList();
    } catch (_) {
      // Fallback: filter tanpa composite index, sort client-side
      final snap = await _recipes
          .where('authorId', isEqualTo: user.uid)
          .get();
      final list = snap.docs.map(CommunityRecipe.fromFirestore).toList();
      list.sort((a, b) =>
          (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)));
      return list;
    }
  }

  Future<void> deleteRecipe(String docId) async {
    await _recipes.doc(docId).delete();
  }

  Future<void> updateCommunityRecipe(String docId, Recipe recipe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Harus login untuk memperbarui resep');

    String imageUrl = recipe.imageUrl;
    if (recipe.imagePath != null && File(recipe.imagePath!).existsSync()) {
      imageUrl = await _uploadLocalImage(recipe.imagePath!, user.uid);
    }

    await _recipes.doc(docId).update({
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
      'updatedAt':   FieldValue.serverTimestamp(),
    });
  }

  // ─── User Profile Sync ───────────────────────────────────────────────────────

  Future<void> syncCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _users.doc(user.uid).set({
        'displayName': user.displayName ?? 'Anonim',
        'photoURL':    user.photoURL ?? '',
        'updatedAt':   FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ─── Follow ───────────────────────────────────────────────────────────────────

  Future<bool> isFollowing(String targetUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == targetUid) return false;
    final doc = await _follows.doc('${user.uid}_$targetUid').get();
    return doc.exists;
  }

  Future<void> followUser(String targetUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == targetUid) return;
    final batch = _db.batch();
    batch.set(_follows.doc('${user.uid}_$targetUid'), {
      'followerId': user.uid,
      'followeeId': targetUid,
      'createdAt':  FieldValue.serverTimestamp(),
    });
    batch.set(_users.doc(user.uid),  {'followingCount': FieldValue.increment(1)},  SetOptions(merge: true));
    batch.set(_users.doc(targetUid), {'followerCount':  FieldValue.increment(1)},  SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> unfollowUser(String targetUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final followDocId = '${user.uid}_$targetUid';
    await _db.runTransaction((tx) async {
      final myDoc     = await tx.get(_users.doc(user.uid));
      final targetDoc = await tx.get(_users.doc(targetUid));
      final myData     = myDoc.exists ? myDoc.data() as Map<String, dynamic> : <String, dynamic>{};
      final targetData = targetDoc.exists ? targetDoc.data() as Map<String, dynamic> : <String, dynamic>{};
      final myFollowing    = (myData['followingCount']     as int? ?? 0).clamp(0, 999999999);
      final targetFollower = (targetData['followerCount']  as int? ?? 0).clamp(0, 999999999);
      tx.delete(_follows.doc(followDocId));
      tx.set(_users.doc(user.uid),  {'followingCount': myFollowing > 0 ? myFollowing - 1 : 0},     SetOptions(merge: true));
      tx.set(_users.doc(targetUid), {'followerCount':  targetFollower > 0 ? targetFollower - 1 : 0}, SetOptions(merge: true));
    });
  }

  Future<PagedResult> getFollowingFeed({DocumentSnapshot? startAfter}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return PagedResult(recipes: [], lastDoc: null, hasMore: false);

    final followSnap = await _follows
        .where('followerId', isEqualTo: user.uid)
        .limit(30)
        .get();
    if (followSnap.docs.isEmpty) {
      return PagedResult(recipes: [], lastDoc: null, hasMore: false);
    }

    final followedUids = followSnap.docs
        .map((d) => (d.data() as Map<String, dynamic>)['followeeId'] as String)
        .toList();
    try {
      Query q = _recipes
          .where('authorId', whereIn: followedUids)
          .orderBy('publishedAt', descending: true)
          .limit(pageSize);
      if (startAfter != null) q = q.startAfterDocument(startAfter);
      final snap    = await q.get();
      final recipes = snap.docs.map(CommunityRecipe.fromFirestore).toList();
      return PagedResult(
        recipes: recipes,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
        hasMore: snap.docs.length == pageSize,
      );
    } catch (_) {
      // Fallback jika composite index belum aktif
      Query q = _recipes.where('authorId', whereIn: followedUids).limit(pageSize);
      if (startAfter != null) q = q.startAfterDocument(startAfter);
      final snap    = await q.get();
      final recipes = snap.docs.map(CommunityRecipe.fromFirestore).toList();
      recipes.sort((a, b) =>
          (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)));
      return PagedResult(
        recipes: recipes,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
        hasMore: snap.docs.length == pageSize,
      );
    }
  }

  // ─── Profile Stats ────────────────────────────────────────────────────────────

  Future<UserProfileStats> getUserStats(String userId) async {
    final results = await Future.wait([
      _recipes.where('authorId', isEqualTo: userId).get(),
      _users.doc(userId).get(),
    ]);

    final snap     = results[0] as QuerySnapshot;
    final userDoc  = results[1] as DocumentSnapshot;
    final recipes  = snap.docs.map(CommunityRecipe.fromFirestore).toList();
    recipes.sort((a, b) =>
        (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)));

    final userData    = userDoc.exists ? userDoc.data() as Map<String, dynamic> : <String, dynamic>{};
    final displayName = (userData['displayName'] as String?)?.isNotEmpty == true
        ? userData['displayName'] as String
        : (recipes.isNotEmpty ? recipes.first.authorName : 'Anonim');
    final photoURL    = (userData['photoURL'] as String?)?.isNotEmpty == true
        ? userData['photoURL'] as String
        : (recipes.isNotEmpty ? recipes.first.authorPhoto : '');

    final totalLikes   = recipes.fold<int>(0, (s, r) => s + r.likes);
    final totalViews   = recipes.fold<int>(0, (s, r) => s + r.viewCount);
    final totalRatings = recipes.fold<int>(0, (s, r) => s + r.ratingCount);
    final weightedSum  = recipes.fold<double>(0, (s, r) => s + r.averageRating * r.ratingCount);
    final avgRating    = totalRatings > 0 ? weightedSum / totalRatings : 0.0;

    return UserProfileStats(
      displayName:    displayName,
      photoURL:       photoURL,
      recipeCount:    recipes.length,
      totalLikes:     totalLikes,
      totalViews:     totalViews,
      averageRating:  avgRating,
      recipes:        recipes,
      followerCount:  ((userData['followerCount']  as int? ?? 0)).clamp(0, 999999999),
      followingCount: ((userData['followingCount'] as int? ?? 0)).clamp(0, 999999999),
    );
  }
}

// ─── Data Models ─────────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime? time;
  final String imageUrl;
  final CommunityRecipe? recipe;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.time,
    this.imageUrl = '',
    this.recipe,
  });
}

class PagedResult {
  final List<CommunityRecipe> recipes;
  final DocumentSnapshot?     lastDoc;
  final bool                  hasMore;
  const PagedResult({required this.recipes, required this.lastDoc, required this.hasMore});
}

class UserProfileStats {
  final String               displayName;
  final String               photoURL;
  final int                  recipeCount;
  final int                  totalLikes;
  final int                  totalViews;
  final double               averageRating;
  final List<CommunityRecipe> recipes;
  final int                  followerCount;
  final int                  followingCount;
  const UserProfileStats({
    this.displayName   = '',
    this.photoURL      = '',
    required this.recipeCount,
    required this.totalLikes,
    required this.totalViews,
    required this.averageRating,
    required this.recipes,
    this.followerCount  = 0,
    this.followingCount = 0,
  });
}

class UserPublicProfile {
  final String uid;
  final String displayName;
  final String photoURL;
  final int    followerCount;
  final int    followingCount;
  const UserPublicProfile({
    required this.uid,
    required this.displayName,
    required this.photoURL,
    this.followerCount  = 0,
    this.followingCount = 0,
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
  final int            viewCount;

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
    this.viewCount = 0,
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
      viewCount:    d['viewCount']    as int? ?? 0,
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
    isOwned:     false,
    calories:    calories,
    protein:     protein,
    carbs:       carbs,
    fat:         fat,
  );
}
