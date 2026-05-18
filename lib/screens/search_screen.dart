import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/recipe_card.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _controller = TextEditingController();
  List<Recipe> _results = [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    final results = await _db.searchRecipes(query.trim());
    setState(() {
      _results = results;
      _hasSearched = true;
    });
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    await _db.toggleFavorite(recipe.id!, !recipe.isFavorite);
    _search(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Cari resep...',
            hintStyle: TextStyle(color: Colors.white60),
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: _search,
        ),
      ),
      body: !_hasSearched
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.search, size: 80, color: AppTheme.textSecondary),
                  SizedBox(height: 16),
                  Text('Ketik nama resep untuk mencari', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            )
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.no_food, size: 80, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      Text('Resep "${_controller.text}" tidak ditemukan', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) => RecipeCard(
                    recipe: _results[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DetailScreen(recipe: _results[i])),
                    ).then((_) => _search(_controller.text)),
                    onFavorite: () => _toggleFavorite(_results[i]),
                  ),
                ),
    );
  }
}
