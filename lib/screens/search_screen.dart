import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/recipe_card.dart';
import '../widgets/error_view.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _db = DatabaseService();
  final _ctrl = TextEditingController();
  List<Recipe> _results = [];
  List<String> _recentSearches = [];
  bool _hasSearched = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _recentSearches = prefs.getStringList('recent_searches') ?? []);
  }

  Future<void> _saveRecent(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    list.remove(query);
    list.insert(0, query);
    if (list.length > 8) list.removeLast();
    await prefs.setStringList('recent_searches', list);
    setState(() => _recentSearches = list);
  }

  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    setState(() => _recentSearches = []);
  }

  Future<void> _search(String query) async {
    query = query.trim();
    if (query.isEmpty) {
      setState(() { _results = []; _hasSearched = false; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    final results = await _db.searchRecipes(query);
    await _saveRecent(query);
    if (mounted) setState(() { _results = results; _hasSearched = true; _loading = false; });
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    await _db.toggleFavorite(recipe.id!, !recipe.isFavorite);
    _search(_ctrl.text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Cari resep, kategori, bahan...',
            hintStyle: TextStyle(color: Colors.white60),
            border: InputBorder.none,
            filled: false,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: _search,
          onSubmitted: _search,
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () { _ctrl.clear(); _search(''); },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : !_hasSearched
              ? _buildInitialState()
              : _results.isEmpty
                  ? EmptyView(
                      icon: Icons.search_off,
                      title: 'Tidak Ditemukan',
                      subtitle: 'Tidak ada resep dengan kata kunci\n"${_ctrl.text.trim()}"',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text('${_results.length} hasil ditemukan',
                            style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13)),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (_, i) => RecipeCard(
                              recipe: _results[i],
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(recipe: _results[i]))).then((_) => _search(_ctrl.text)),
                              onFavorite: () => _toggleFavorite(_results[i]),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildInitialState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Row(children: [
            const Text('Pencarian Terakhir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            TextButton(onPressed: _clearRecent, child: Text('Hapus', style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13))),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((q) => GestureDetector(
              onTap: () { _ctrl.text = q; _search(q); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history, size: 16, color: AppTheme.textSubOn(context)),
                  const SizedBox(width: 6),
                  Text(q, style: const TextStyle(fontSize: 14)),
                ]),
              ),
            )).toList(),
          ),
        ] else
          const EmptyView(
            icon: Icons.search,
            title: 'Cari Resep',
            subtitle: 'Ketik nama resep, kategori, atau bahan untuk mencari',
          ),
      ],
    );
  }
}
