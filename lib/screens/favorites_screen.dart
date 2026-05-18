import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../widgets/recipe_card.dart';
import '../widgets/shimmer_card.dart';
import '../widgets/error_view.dart';
import 'detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _db = DatabaseService();
  List<Recipe> _favorites = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final favs = await _db.getFavorites();
      if (mounted) setState(() { _favorites = favs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  Future<void> _removeFavorite(Recipe recipe) async {
    await _db.toggleFavorite(recipe.id!, false);
    _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${recipe.title}" dihapus dari favorit'),
      action: SnackBarAction(
        label: 'Batalkan',
        textColor: Colors.amber,
        onPressed: () async {
          await _db.toggleFavorite(recipe.id!, true);
          _load();
        },
      ),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resep Favorit')),
      body: _hasError
          ? ErrorView(message: 'Gagal memuat favorit', onRetry: _load)
          : _loading
              ? const ShimmerList(count: 3)
              : _favorites.isEmpty
                  ? const EmptyView(
                      icon: Icons.favorite_border,
                      title: 'Belum Ada Favorit',
                      subtitle: 'Tekan ikon hati pada resep\nuntuk menambahkan ke favorit',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _favorites.length,
                        itemBuilder: (_, i) => Dismissible(
                          key: Key('fav_${_favorites[i].id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.favorite_border, color: Colors.white),
                          ),
                          onDismissed: (_) => _removeFavorite(_favorites[i]),
                          child: RecipeCard(
                            recipe: _favorites[i],
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(recipe: _favorites[i]))).then((_) => _load()),
                            onFavorite: () => _removeFavorite(_favorites[i]),
                          ),
                        ),
                      ),
                    ),
    );
  }
}
