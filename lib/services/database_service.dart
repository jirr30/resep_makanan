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
      version: 3,
      onCreate: (db, _) async {
        await _createAllTables(db);
        await _insertSampleData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
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
      },
    );
  }

  Future<void> _createAllTables(Database db) async {
    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL, category TEXT NOT NULL,
        description TEXT NOT NULL, imageUrl TEXT NOT NULL,
        imagePath TEXT, ingredients TEXT NOT NULL, steps TEXT NOT NULL,
        cookingTime INTEGER NOT NULL, servings INTEGER NOT NULL,
        rating REAL NOT NULL DEFAULT 0, userRating REAL NOT NULL DEFAULT 0,
        difficulty TEXT NOT NULL, isFavorite INTEGER NOT NULL DEFAULT 0,
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
  }

  Future<void> _insertSampleData(Database db) async {
    final samples = [
      {'title':'Nasi Goreng Spesial','category':'Makanan Utama','description':'Nasi goreng lezat dengan bumbu rempah khas Indonesia yang menggugah selera.','imageUrl':'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=400','ingredients':'Nasi putih 2 piring||Telur 2 butir||Bawang merah 5 siung||Bawang putih 3 siung||Cabai merah 3 buah||Kecap manis 2 sdm||Garam secukupnya||Minyak goreng 3 sdm||Daun bawang 2 batang||Tomat 1 buah','steps':'Panaskan minyak goreng di wajan||Tumis bawang merah, bawang putih, dan cabai hingga harum||Masukkan telur, orak-arik hingga matang||Tambahkan nasi, aduk rata||Beri kecap manis dan garam||Masak hingga nasi matang merata||Taburi daun bawang dan sajikan','cookingTime':20,'servings':2,'rating':4.5,'userRating':0.0,'difficulty':'Mudah','isFavorite':0,'calories':450,'protein':12.0,'carbs':70.0,'fat':14.0},
      {'title':'Soto Ayam','category':'Sup','description':'Sup ayam khas Indonesia dengan kuah bening yang segar dan kaya rempah.','imageUrl':'https://images.unsplash.com/photo-1547592180-85f173990554?w=400','ingredients':'Ayam 1/2 ekor||Bawang merah 8 siung||Bawang putih 5 siung||Jahe 2 cm||Kunyit 2 cm||Serai 2 batang||Daun jeruk 5 lembar||Garam secukupnya||Air 2 liter||Taoge secukupnya||Mie bihun secukupnya||Telur rebus 2 butir','steps':'Rebus ayam bersama bumbu halus dan rempah||Masak dengan api sedang selama 45 menit||Angkat ayam, suwir-suwir dagingnya||Saring kaldu dan panaskan kembali||Siapkan mangkuk, isi dengan bihun dan taoge||Siram dengan kuah panas||Sajikan dengan telur rebus','cookingTime':60,'servings':4,'rating':4.8,'userRating':0.0,'difficulty':'Sedang','isFavorite':0,'calories':320,'protein':28.0,'carbs':25.0,'fat':10.0},
      {'title':'Rendang Daging','category':'Makanan Utama','description':'Rendang daging sapi yang empuk dan kaya bumbu, masakan khas Minangkabau.','imageUrl':'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400','ingredients':'Daging sapi 500 gram||Santan kental 400 ml||Bawang merah 10 siung||Bawang putih 6 siung||Cabai merah 10 buah||Jahe 3 cm||Lengkuas 3 cm||Serai 3 batang||Daun kunyit 2 lembar||Kayu manis 1 batang||Garam secukupnya','steps':'Haluskan semua bumbu rempah||Tumis bumbu halus hingga harum dan matang||Masukkan daging sapi, aduk rata||Tuang santan kental, aduk perlahan||Masak dengan api kecil sambil sesekali diaduk||Masak hingga santan menyusut dan daging mengering||Rendang siap disajikan','cookingTime':180,'servings':6,'rating':4.9,'userRating':0.0,'difficulty':'Sulit','isFavorite':0,'calories':580,'protein':35.0,'carbs':10.0,'fat':42.0},
      {'title':'Gado-Gado','category':'Salad','description':'Salad sayuran segar dengan saus kacang yang lezat, makanan sehat khas Indonesia.','imageUrl':'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400','ingredients':'Kangkung 200 gram||Taoge 100 gram||Kentang 2 buah||Tahu 4 potong||Tempe 4 potong||Telur rebus 2 butir||Kacang tanah 200 gram||Cabai merah 3 buah||Bawang putih 2 siung||Kecap manis 2 sdm||Air jeruk nipis 1 sdm||Gula merah secukupnya||Garam secukupnya','steps':'Goreng kacang tanah hingga matang, haluskan||Tumis cabai dan bawang putih, haluskan||Campurkan kacang dan bumbu, tambahkan air||Beri kecap, gula merah, garam, dan jeruk nipis||Rebus sayuran hingga matang||Goreng tahu dan tempe||Tata semua bahan, siram saus kacang','cookingTime':40,'servings':4,'rating':4.3,'userRating':0.0,'difficulty':'Mudah','isFavorite':0,'calories':380,'protein':18.0,'carbs':35.0,'fat':20.0},
      {'title':'Martabak Manis','category':'Dessert','description':'Kue tebal manis dengan berbagai topping lezat, jajanan malam favorit.','imageUrl':'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400','ingredients':'Tepung terigu 250 gram||Telur 2 butir||Susu cair 200 ml||Ragi 1 sdt||Gula pasir 3 sdm||Garam 1/2 sdt||Margarin secukupnya||Cokelat meises secukupnya||Keju parut secukupnya||Susu kental manis secukupnya','steps':'Campur tepung, gula, garam, dan ragi||Tambahkan telur dan susu, aduk hingga licin||Diamkan adonan 30 menit||Panaskan wajan datar, olesi margarin||Tuang adonan, masak hingga berlubang-lubang||Taburkan topping yang diinginkan||Lipat dua dan sajikan hangat','cookingTime':45,'servings':8,'rating':4.7,'userRating':0.0,'difficulty':'Sedang','isFavorite':0,'calories':290,'protein':6.0,'carbs':45.0,'fat':10.0},
      {'title':'Ayam Bakar Kecap','category':'Makanan Utama','description':'Ayam bakar dengan bumbu kecap yang manis gurih, sempurna untuk makan siang.','imageUrl':'https://images.unsplash.com/photo-1598103442097-8b74394b95c3?w=400','ingredients':'Ayam 1 ekor potong 8||Kecap manis 5 sdm||Bawang merah 6 siung||Bawang putih 4 siung||Jahe 2 cm||Ketumbar 1 sdt||Garam secukupnya||Minyak untuk menumis','steps':'Haluskan bawang merah, bawang putih, jahe, ketumbar||Tumis bumbu halus hingga harum||Masukkan ayam, aduk rata||Tambahkan kecap manis dan sedikit air||Masak hingga ayam setengah matang||Bakar ayam di atas bara api atau grill pan||Olesi sisa bumbu saat dibakar','cookingTime':50,'servings':4,'rating':4.6,'userRating':0.0,'difficulty':'Sedang','isFavorite':0,'calories':340,'protein':30.0,'carbs':15.0,'fat':18.0},
    ];
    for (final r in samples) { await db.insert('recipes', r); }
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
        where: 'title LIKE ? OR category LIKE ? OR description LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%']);
      return maps.map(Recipe.fromMap).toList();
    } catch (_) { return []; }
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
