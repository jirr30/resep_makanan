import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/recipe_card.dart';
import 'detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final DatabaseService _db = DatabaseService();
  List<Recipe> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    final favs = await _db.getFavorites();
    setState(() {
      _favorites = favs;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    await _db.toggleFavorite(recipe.id!, false);
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resep Favorit')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.favorite_border, size: 80, color: AppTheme.textSecondary),
                      SizedBox(height: 16),
                      Text('Belum ada resep favorit', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
                      SizedBox(height: 8),
                      Text('Tambahkan resep ke favorit\ndengan menekan ikon hati', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: ListView.builder(
                    itemCount: _favorites.length,
                    itemBuilder: (_, i) => RecipeCard(
                      recipe: _favorites[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetailScreen(recipe: _favorites[i])),
                      ).then((_) => _loadFavorites()),
                      onFavorite: () => _toggleFavorite(_favorites[i]),
                    ),
                  ),
                ),
    );
  }
}
