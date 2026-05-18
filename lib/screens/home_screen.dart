import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/recipe_card.dart';
import 'detail_screen.dart';
import 'add_recipe_screen.dart';
import 'favorites_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  List<Recipe> _recipes = [];
  List<String> _customCategories = [];
  String _selectedCategory = 'Semua';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final customCats = await _db.getCustomCategories();
    final recipes = _selectedCategory == 'Semua'
        ? await _db.getAllRecipes()
        : await _db.getByCategory(_selectedCategory);
    setState(() {
      _customCategories = customCats;
      _recipes = recipes;
      _loading = false;
    });
  }

  List<String> get _allCategories =>
      [...AppConstants.categories, ..._customCategories.where((c) => !AppConstants.categories.contains(c))];

  Future<void> _toggleFavorite(Recipe recipe) async {
    await _db.toggleFavorite(recipe.id!, !recipe.isFavorite);
    _load();
  }

  Future<void> _showAddCategoryDialog() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Kategori Baru'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama kategori...'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Tambah')),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty) {
      await _db.addCustomCategory(result);
      _load();
    }
  }

  Future<void> _deleteCustomCategory(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text('Kategori "$name" akan dihapus.\nResep dengan kategori ini tidak ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteCustomCategory(name);
      if (_selectedCategory == name) _selectedCategory = 'Semua';
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ResepKu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))
                .then((_) => _load()),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBanner(),
          _buildCategories(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _recipes.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _recipes.length,
                          itemBuilder: (_, i) => RecipeCard(
                            recipe: _recipes[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => DetailScreen(recipe: _recipes[i])),
                            ).then((_) => _load()),
                            onFavorite: () => _toggleFavorite(_recipes[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddRecipeScreen()))
            .then((_) => _load()),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Resep', style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()))
                .then((_) => _load());
          }
        },
        selectedItemColor: AppTheme.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorit'),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFFFF8C55)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mau masak apa hari ini?', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Temukan Resep\nTerbaik!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Text('${_recipes.length} Resep Tersedia', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ])),
        const Icon(Icons.restaurant_menu, color: Colors.white30, size: 80),
      ]),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _allCategories.length + 1, // +1 untuk tombol tambah
        itemBuilder: (_, i) {
          if (i == _allCategories.length) {
            return GestureDetector(
              onTap: _showAddCategoryDialog,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary),
                ),
                child: const Row(children: [
                  Icon(Icons.add, size: 16, color: AppTheme.primary),
                  SizedBox(width: 4),
                  Text('Kategori', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                ]),
              ),
            );
          }
          final cat = _allCategories[i];
          final selected = cat == _selectedCategory;
          final isCustom = !AppConstants.categories.contains(cat);
          return GestureDetector(
            onTap: () { setState(() => _selectedCategory = cat); _load(); },
            onLongPress: isCustom ? () => _deleteCustomCategory(cat) : null,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              padding: EdgeInsets.symmetric(horizontal: isCustom ? 10 : 16),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppTheme.primary : const Color(0xFFDFE6E9)),
              ),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(cat, style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                )),
                if (isCustom) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.circle, size: 6, color: selected ? Colors.white60 : AppTheme.primary),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.no_food, size: 80, color: AppTheme.textSecondary),
        const SizedBox(height: 16),
        const Text('Belum ada resep di kategori ini', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddRecipeScreen())).then((_) => _load()),
          child: const Text('Tambah Resep'),
        ),
      ]),
    );
  }
}
