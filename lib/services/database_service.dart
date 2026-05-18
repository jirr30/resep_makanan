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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE recipes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL,
            imageUrl TEXT NOT NULL,
            ingredients TEXT NOT NULL,
            steps TEXT NOT NULL,
            cookingTime INTEGER NOT NULL,
            servings INTEGER NOT NULL,
            rating REAL NOT NULL,
            difficulty TEXT NOT NULL,
            isFavorite INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await _insertSampleData(db);
      },
    );
  }

  Future<void> _insertSampleData(Database db) async {
    final samples = [
      {
        'title': 'Nasi Goreng Spesial',
        'category': 'Makanan Utama',
        'description': 'Nasi goreng lezat dengan bumbu rempah khas Indonesia yang menggugah selera.',
        'imageUrl': 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=400',
        'ingredients': 'Nasi putih 2 piring||Telur 2 butir||Bawang merah 5 siung||Bawang putih 3 siung||Cabai merah 3 buah||Kecap manis 2 sdm||Garam secukupnya||Minyak goreng 3 sdm||Daun bawang 2 batang||Tomat 1 buah',
        'steps': 'Panaskan minyak goreng di wajan||Tumis bawang merah, bawang putih, dan cabai hingga harum||Masukkan telur, orak-arik hingga matang||Tambahkan nasi, aduk rata||Beri kecap manis dan garam, aduk kembali||Masak hingga nasi matang merata||Taburi daun bawang dan sajikan',
        'cookingTime': 20,
        'servings': 2,
        'rating': 4.5,
        'difficulty': 'Mudah',
        'isFavorite': 0,
      },
      {
        'title': 'Soto Ayam',
        'category': 'Sup',
        'description': 'Sup ayam khas Indonesia dengan kuah bening yang segar dan kaya rempah.',
        'imageUrl': 'https://images.unsplash.com/photo-1547592180-85f173990554?w=400',
        'ingredients': 'Ayam 1/2 ekor||Bawang merah 8 siung||Bawang putih 5 siung||Jahe 2 cm||Kunyit 2 cm||Serai 2 batang||Daun jeruk 5 lembar||Garam secukupnya||Air 2 liter||Taoge secukupnya||Mie bihun secukupnya||Telur rebus 2 butir',
        'steps': 'Rebus ayam bersama bumbu halus dan rempah||Masak dengan api sedang selama 45 menit||Angkat ayam, suwir-suwir dagingnya||Saring kaldu dan panaskan kembali||Siapkan mangkuk, isi dengan bihun, taoge, suwiran ayam||Siram dengan kuah panas||Sajikan dengan telur rebus dan pelengkap',
        'cookingTime': 60,
        'servings': 4,
        'rating': 4.8,
        'difficulty': 'Sedang',
        'isFavorite': 0,
      },
      {
        'title': 'Rendang Daging',
        'category': 'Makanan Utama',
        'description': 'Rendang daging sapi yang empuk dan kaya bumbu, masakan khas Minangkabau.',
        'imageUrl': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=400',
        'ingredients': 'Daging sapi 500 gram||Santan kental 400 ml||Bawang merah 10 siung||Bawang putih 6 siung||Cabai merah 10 buah||Jahe 3 cm||Lengkuas 3 cm||Serai 3 batang||Daun kunyit 2 lembar||Kayu manis 1 batang||Garam secukupnya',
        'steps': 'Haluskan semua bumbu rempah||Tumis bumbu halus hingga harum dan matang||Masukkan daging sapi, aduk rata||Tuang santan kental, aduk perlahan||Masak dengan api kecil sambil sesekali diaduk||Masak hingga santan menyusut dan daging mengering||Rendang siap disajikan saat berwarna cokelat kehitaman',
        'cookingTime': 180,
        'servings': 6,
        'rating': 4.9,
        'difficulty': 'Sulit',
        'isFavorite': 0,
      },
      {
        'title': 'Gado-Gado',
        'category': 'Salad',
        'description': 'Salad sayuran segar dengan saus kacang yang lezat, makanan sehat khas Indonesia.',
        'imageUrl': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400',
        'ingredients': 'Kangkung 200 gram||Taoge 100 gram||Kentang 2 buah||Tahu 4 potong||Tempe 4 potong||Telur rebus 2 butir||Kacang tanah 200 gram||Cabai merah 3 buah||Bawang putih 2 siung||Kecap manis 2 sdm||Air jeruk nipis 1 sdm||Gula merah secukupnya||Garam secukupnya',
        'steps': 'Goreng kacang tanah hingga matang, haluskan||Tumis cabai dan bawang putih, haluskan||Campurkan kacang dan bumbu, tambahkan air secukupnya||Beri kecap, gula merah, garam, dan jeruk nipis||Rebus sayuran hingga matang||Goreng tahu dan tempe||Tata semua bahan di piring, siram saus kacang',
        'cookingTime': 40,
        'servings': 4,
        'rating': 4.3,
        'difficulty': 'Mudah',
        'isFavorite': 0,
      },
      {
        'title': 'Martabak Manis',
        'category': 'Dessert',
        'description': 'Kue tebal manis dengan berbagai topping lezat, jajanan malam favorit.',
        'imageUrl': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400',
        'ingredients': 'Tepung terigu 250 gram||Telur 2 butir||Susu cair 200 ml||Ragi 1 sdt||Gula pasir 3 sdm||Garam 1/2 sdt||Margarin secukupnya||Cokelat meises secukupnya||Keju parut secukupnya||Susu kental manis secukupnya',
        'steps': 'Campur tepung, gula, garam, dan ragi||Tambahkan telur dan susu, aduk hingga licin||Diamkan adonan 30 menit||Panaskan wajan datar, olesi margarin||Tuang adonan, masak hingga berlubang-lubang||Taburkan topping yang diinginkan||Lipat dua dan sajikan hangat',
        'cookingTime': 45,
        'servings': 8,
        'rating': 4.7,
        'difficulty': 'Sedang',
        'isFavorite': 0,
      },
      {
        'title': 'Ayam Bakar Kecap',
        'category': 'Makanan Utama',
        'description': 'Ayam bakar dengan bumbu kecap yang manis gurih, sempurna untuk makan siang.',
        'imageUrl': 'https://images.unsplash.com/photo-1598103442097-8b74394b95c3?w=400',
        'ingredients': 'Ayam 1 ekor potong 8||Kecap manis 5 sdm||Bawang merah 6 siung||Bawang putih 4 siung||Jahe 2 cm||Ketumbar 1 sdt||Garam secukupnya||Minyak untuk menumis',
        'steps': 'Haluskan bawang merah, bawang putih, jahe, ketumbar||Tumis bumbu halus hingga harum||Masukkan ayam, aduk rata||Tambahkan kecap manis dan sedikit air||Masak hingga ayam setengah matang||Bakar ayam di atas bara api atau grill pan||Olesi sisa bumbu saat dibakar hingga matang',
        'cookingTime': 50,
        'servings': 4,
        'rating': 4.6,
        'difficulty': 'Sedang',
        'isFavorite': 0,
      },
    ];

    for (final recipe in samples) {
      await db.insert('recipes', recipe);
    }
  }

  Future<List<Recipe>> getAllRecipes() async {
    final db = await database;
    final maps = await db.query('recipes', orderBy: 'id DESC');
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  Future<List<Recipe>> getFavorites() async {
    final db = await database;
    final maps = await db.query('recipes', where: 'isFavorite = ?', whereArgs: [1]);
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    final db = await database;
    final maps = await db.query(
      'recipes',
      where: 'title LIKE ? OR category LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  Future<List<Recipe>> getByCategory(String category) async {
    final db = await database;
    final maps = await db.query('recipes', where: 'category = ?', whereArgs: [category]);
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  Future<int> insertRecipe(Recipe recipe) async {
    final db = await database;
    return db.insert('recipes', recipe.toMap());
  }

  Future<void> toggleFavorite(int id, bool isFavorite) async {
    final db = await database;
    await db.update('recipes', {'isFavorite': isFavorite ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteRecipe(int id) async {
    final db = await database;
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }
}
