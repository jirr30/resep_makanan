import 'package:sqflite/sqflite.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import '../models/recipe.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'resep_makanan.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: (db, _) async {
        await _createAllTables(db);
        // Tidak ada seed data — user mulai dari nol
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 7) {
          await db.execute('''CREATE TABLE IF NOT EXISTS collections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            createdAt TEXT NOT NULL)''');
          await db.execute('''CREATE TABLE IF NOT EXISTS collection_recipes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            collectionId INTEGER NOT NULL,
            recipeId INTEGER NOT NULL,
            addedAt TEXT NOT NULL,
            UNIQUE(collectionId, recipeId))''');
        }
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE recipes ADD COLUMN userRating REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE recipes ADD COLUMN imagePath TEXT');
          await db.execute('ALTER TABLE recipes ADD COLUMN calories INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE recipes ADD COLUMN protein REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE recipes ADD COLUMN carbs REAL NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE recipes ADD COLUMN fat REAL NOT NULL DEFAULT 0');
          await db.execute('''CREATE TABLE IF NOT EXISTS custom_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)''');
        }
        if (oldVersion < 3) {
          await db.execute('''CREATE TABLE IF NOT EXISTS shopping_list (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            quantity TEXT,
            isChecked INTEGER NOT NULL DEFAULT 0,
            recipeId INTEGER,
            createdAt TEXT NOT NULL)''');
          await db.execute('''CREATE TABLE IF NOT EXISTS meal_plans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            mealType TEXT NOT NULL,
            recipeId INTEGER NOT NULL)''');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE recipes ADD COLUMN firestoreId TEXT');
        }
        if (oldVersion < 5) {
          // Hapus resep contoh yang di-seed saat versi pertama
          await db.delete(
            'recipes',
            where: "title IN (?,?,?,?,?,?) AND imageUrl LIKE '%unsplash%'",
            whereArgs: [
              'Nasi Goreng Spesial', 'Soto Ayam', 'Rendang Daging',
              'Gado-Gado', 'Martabak Manis', 'Ayam Bakar Kecap',
            ],
          );
        }
        if (oldVersion < 6) {
          // Resep yang sudah ada adalah milik user sendiri (default 1 = true)
          await db.execute(
            'ALTER TABLE recipes ADD COLUMN isOwned INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
    );
  }

  Future<void> _createAllTables(Database db) async {
    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL, category TEXT NOT NULL,
        description TEXT NOT NULL, imageUrl TEXT NOT NULL,
        imagePath TEXT, firestoreId TEXT,
        ingredients TEXT NOT NULL, steps TEXT NOT NULL,
        cookingTime INTEGER NOT NULL, servings INTEGER NOT NULL,
        rating REAL NOT NULL DEFAULT 0, userRating REAL NOT NULL DEFAULT 0,
        difficulty TEXT NOT NULL, isFavorite INTEGER NOT NULL DEFAULT 0,
        isOwned INTEGER NOT NULL DEFAULT 1,
        calories INTEGER NOT NULL DEFAULT 0, protein REAL NOT NULL DEFAULT 0,
        carbs REAL NOT NULL DEFAULT 0, fat REAL NOT NULL DEFAULT 0)''');
    await db.execute('''
      CREATE TABLE custom_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)''');
    await db.execute('''
      CREATE TABLE shopping_list (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, quantity TEXT,
        isChecked INTEGER NOT NULL DEFAULT 0,
        recipeId INTEGER, createdAt TEXT NOT NULL)''');
    await db.execute('''
      CREATE TABLE meal_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL, mealType TEXT NOT NULL,
        recipeId INTEGER NOT NULL)''');
    await db.execute('''
      CREATE TABLE collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL)''');
    await db.execute('''
      CREATE TABLE collection_recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collectionId INTEGER NOT NULL,
        recipeId INTEGER NOT NULL,
        addedAt TEXT NOT NULL,
        UNIQUE(collectionId, recipeId))''');
  }

  // ── Recipes ──────────────────────────────────────────────────────────────

  Future<List<Recipe>> getAllRecipes() async {
    try {
      final db = await database;
      final maps = await db.query('recipes', orderBy: 'id DESC');
      return maps.map(Recipe.fromMap).toList();
    } catch (_) { return []; }
  }

  Future<List<Recipe>> getFavorites() async {
    try {
      final db = await database;
      final maps = await db.query('recipes', where: 'isFavorite = ?', whereArgs: [1]);
      return maps.map(Recipe.fromMap).toList();
    } catch (_) { return []; }
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    try {
      final db = await database;
      final maps = await db.query('recipes',
        where: 'title LIKE ? OR category LIKE ? OR description LIKE ? OR ingredients LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%']);
      return maps.map(Recipe.fromMap).toList();
    } catch (_) { return []; }
  }

  Future<Recipe?> getRecipeByFirestoreId(String firestoreId) async {
    try {
      final db = await database;
      final rows = await db.query('recipes',
          where: 'firestoreId = ?',
          whereArgs: [firestoreId],
          limit: 1);
      if (rows.isEmpty) return null;
      return Recipe.fromMap(rows.first);
    } catch (_) { return null; }
  }

  Future<List<Recipe>> getByCategory(String category) async {
    try {
      final db = await database;
      final maps = await db.query('recipes', where: 'category = ?', whereArgs: [category]);
      return maps.map(Recipe.fromMap).toList();
    } catch (_) { return []; }
  }

  Future<int> insertRecipe(Recipe recipe) async {
    final db = await database;
    return db.insert('recipes', recipe.toMap());
  }

  Future<bool> isCommunityRecipeSaved(String firestoreId) async {
    try {
      final db = await database;
      final rows = await db.query('recipes',
          where: 'firestoreId = ?',
          whereArgs: [firestoreId],
          limit: 1);
      return rows.isNotEmpty;
    } catch (_) { return false; }
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final db = await database;
    await db.update('recipes', recipe.toMap(), where: 'id = ?', whereArgs: [recipe.id]);
  }

  Future<void> toggleFavorite(int id, bool isFavorite) async {
    final db = await database;
    await db.update('recipes', {'isFavorite': isFavorite ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateUserRating(int id, double rating) async {
    final db = await database;
    await db.update('recipes', {'userRating': rating}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteRecipe(int id) async {
    final db = await database;
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
    await db.delete('meal_plans', where: 'recipeId = ?', whereArgs: [id]);
  }

  // ── Custom Categories ─────────────────────────────────────────────────────

  Future<List<String>> getCustomCategories() async {
    try {
      final db = await database;
      final maps = await db.query('custom_categories', orderBy: 'name ASC');
      return maps.map((m) => m['name'] as String).toList();
    } catch (_) { return []; }
  }

  Future<void> addCustomCategory(String name) async {
    final db = await database;
    await db.insert('custom_categories', {'name': name}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> deleteCustomCategory(String name) async {
    final db = await database;
    await db.delete('custom_categories', where: 'name = ?', whereArgs: [name]);
  }

  // ── Shopping List ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getShoppingList() async {
    try {
      final db = await database;
      return db.query('shopping_list', orderBy: 'isChecked ASC, createdAt ASC');
    } catch (_) { return []; }
  }

  Future<void> addShoppingItem(String name, {String? quantity, int? recipeId}) async {
    final db = await database;
    await db.insert('shopping_list', {
      'name': name, 'quantity': quantity, 'isChecked': 0,
      'recipeId': recipeId, 'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> addIngredientsToShoppingList(Recipe recipe) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final ingredient in recipe.ingredients) {
      batch.insert('shopping_list', {
        'name': ingredient, 'quantity': null, 'isChecked': 0,
        'recipeId': recipe.id, 'createdAt': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> addStringListToShoppingList(List<String> ingredients) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final ingredient in ingredients) {
      if (ingredient.trim().isEmpty) continue;
      batch.insert('shopping_list', {
        'name': ingredient.trim(), 'quantity': null, 'isChecked': 0,
        'recipeId': null, 'createdAt': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> toggleShoppingItem(int id, bool isChecked) async {
    final db = await database;
    await db.update('shopping_list', {'isChecked': isChecked ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteShoppingItem(int id) async {
    final db = await database;
    await db.delete('shopping_list', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearCheckedShoppingItems() async {
    final db = await database;
    await db.delete('shopping_list', where: 'isChecked = ?', whereArgs: [1]);
  }

  Future<void> clearAllShoppingItems() async {
    final db = await database;
    await db.delete('shopping_list');
  }

  // ── Meal Planner ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMealPlansForWeek(List<String> dates) async {
    try {
      final db = await database;
      if (dates.isEmpty) return [];
      final placeholders = List.filled(dates.length, '?').join(',');
      return db.rawQuery(
        'SELECT mp.*, r.title, r.imageUrl, r.imagePath, r.cookingTime FROM meal_plans mp '
        'JOIN recipes r ON mp.recipeId = r.id WHERE mp.date IN ($placeholders) ORDER BY mp.date, mp.mealType',
        dates,
      );
    } catch (_) { return []; }
  }

  Future<void> addMealPlan(String date, String mealType, int recipeId) async {
    final db = await database;
    await db.insert('meal_plans', {'date': date, 'mealType': mealType, 'recipeId': recipeId},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMealPlan(int id) async {
    final db = await database;
    await db.delete('meal_plans', where: 'id = ?', whereArgs: [id]);
  }

  // ── Collections (Folder Resep) ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCollections() async {
    try {
      final db = await database;
      final cols = await db.query('collections', orderBy: 'createdAt DESC');
      final result = <Map<String, dynamic>>[];
      for (final col in cols) {
        final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM collection_recipes WHERE collectionId = ?',
          [col['id']],
        )) ?? 0;
        result.add({...col, 'recipeCount': count});
      }
      return result;
    } catch (_) { return []; }
  }

  Future<int> createCollection(String name) async {
    final db = await database;
    return db.insert('collections', {
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteCollection(int id) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('collection_recipes', where: 'collectionId = ?', whereArgs: [id]);
    batch.delete('collections', where: 'id = ?', whereArgs: [id]);
    await batch.commit(noResult: true);
  }

  Future<void> addRecipeToCollection(int collectionId, int recipeId) async {
    final db = await database;
    await db.insert(
      'collection_recipes',
      {'collectionId': collectionId, 'recipeId': recipeId, 'addedAt': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeRecipeFromCollection(int collectionId, int recipeId) async {
    final db = await database;
    await db.delete('collection_recipes',
        where: 'collectionId = ? AND recipeId = ?',
        whereArgs: [collectionId, recipeId]);
  }

  Future<List<Recipe>> getCollectionRecipes(int collectionId) async {
    try {
      final db = await database;
      final maps = await db.rawQuery(
        'SELECT r.* FROM recipes r '
        'JOIN collection_recipes cr ON r.id = cr.recipeId '
        'WHERE cr.collectionId = ? ORDER BY cr.addedAt DESC',
        [collectionId],
      );
      return maps.map(Recipe.fromMap).toList();
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> getCollectionsForRecipe(int recipeId) async {
    try {
      final db = await database;
      return db.rawQuery(
        'SELECT c.*, (SELECT COUNT(*) FROM collection_recipes cr2 WHERE cr2.collectionId = c.id) as recipeCount, '
        '(SELECT COUNT(*) FROM collection_recipes cr3 WHERE cr3.collectionId = c.id AND cr3.recipeId = ?) as isAdded '
        'FROM collections c ORDER BY c.createdAt DESC',
        [recipeId],
      );
    } catch (_) { return []; }
  }

  Future<void> renameCollection(int id, String newName) async {
    final db = await database;
    await db.update('collections', {'name': newName}, where: 'id = ?', whereArgs: [id]);
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  Future<void> clearAllLocalData() async {
    final db = await database;
    await db.delete('collection_recipes');
    await db.delete('collections');
    await db.delete('meal_plans');
    await db.delete('shopping_list');
    await db.delete('custom_categories');
    await db.delete('recipes');
  }

  // ── Backup ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> exportAllData() async {
    final db = await database;
    return db.query('recipes');
  }

  Future<void> importRecipes(List<Map<String, dynamic>> recipes) async {
    final db = await database;
    final batch = db.batch();
    for (final r in recipes) {
      final data = Map<String, dynamic>.from(r)..remove('id');
      batch.insert('recipes', data, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }
}
