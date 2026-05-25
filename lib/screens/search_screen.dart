import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../widgets/recipe_card.dart';
import '../widgets/error_view.dart';
import 'community_detail_screen.dart';
import 'detail_screen.dart';

enum _SearchMode { local, community }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _db = DatabaseService();
  final _fs = FirestoreService();
  final _ctrl = TextEditingController();

  List<Recipe> _localResults = [];
  List<CommunityRecipe> _communityResults = [];
  List<CommunityRecipe>? _communityCache;

  List<String> _recentSearches = [];
  bool _hasSearched = false;
  bool _loading = false;
  _SearchMode _mode = _SearchMode.local;

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
      setState(() {
        _localResults = [];
        _communityResults = [];
        _hasSearched = false;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);

    if (_mode == _SearchMode.local) {
      final results = await _db.searchRecipes(query);
      await _saveRecent(query);
      if (mounted) {
        setState(() { _localResults = results; _hasSearched = true; _loading = false; });
      }
    } else {
      await _saveRecent(query);
      // Gunakan cache agar tidak reload tiap keystroke
      _communityCache ??= await _fs.getAllRecipesForSearch();
      final q = query.toLowerCase();
      final results = (_communityCache ?? []).where((r) =>
        r.title.toLowerCase().contains(q) ||
        r.category.toLowerCase().contains(q) ||
        r.description.toLowerCase().contains(q) ||
        r.ingredients.any((i) => i.toLowerCase().contains(q))
      ).toList();
      if (mounted) {
        setState(() { _communityResults = results; _hasSearched = true; _loading = false; });
      }
    }
  }

  void _switchMode(_SearchMode mode) {
    if (_mode == mode) return;
    // Reset cache komunitas agar data segar saat kembali ke mode komunitas
    if (mode == _SearchMode.community) _communityCache = null;
    setState(() {
      _mode = mode;
      _localResults = [];
      _communityResults = [];
      _hasSearched = false;
    });
    if (_ctrl.text.trim().isNotEmpty) _search(_ctrl.text);
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
      body: Column(
        children: [
          // Mode toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [
              _ModeChip(
                label: 'Resep Saya',
                icon: Icons.book_outlined,
                selected: _mode == _SearchMode.local,
                onTap: () => _switchMode(_SearchMode.local),
              ),
              const SizedBox(width: 10),
              _ModeChip(
                label: 'Komunitas',
                icon: Icons.people_outline,
                selected: _mode == _SearchMode.community,
                onTap: () => _switchMode(_SearchMode.community),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : !_hasSearched
                    ? _buildInitialState()
                    : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_mode == _SearchMode.local) {
      if (_localResults.isEmpty) {
        return EmptyView(
          icon: Icons.search_off,
          title: 'Tidak Ditemukan',
          subtitle: 'Tidak ada resep dengan kata kunci\n"${_ctrl.text.trim()}"',
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text('${_localResults.length} hasil ditemukan',
              style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _localResults.length,
            itemBuilder: (_, i) => RecipeCard(
              recipe: _localResults[i],
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => DetailScreen(recipe: _localResults[i])),
              ).then((_) => _search(_ctrl.text)),
            ),
          ),
        ),
      ]);
    } else {
      if (_communityResults.isEmpty) {
        return EmptyView(
          icon: Icons.search_off,
          title: 'Tidak Ditemukan',
          subtitle: 'Tidak ada resep komunitas dengan kata kunci\n"${_ctrl.text.trim()}"',
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text('${_communityResults.length} hasil di komunitas',
              style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _communityResults.length,
            itemBuilder: (_, i) {
              final r = _communityResults[i];
              return _CommunitySearchCard(
                recipe: r,
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => CommunityDetailScreen(recipe: r)),
                ),
              );
            },
          ),
        ),
      ]);
    }
  }

  Widget _buildInitialState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Row(children: [
            const Text('Pencarian Terakhir',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            TextButton(
              onPressed: _clearRecent,
              child: Text('Hapus',
                  style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13)),
            ),
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
          EmptyView(
            icon: _mode == _SearchMode.community ? Icons.people_outline : Icons.search,
            title: _mode == _SearchMode.community ? 'Cari Resep Komunitas' : 'Cari Resep',
            subtitle: _mode == _SearchMode.community
                ? 'Temukan resep yang dibagikan pengguna lain'
                : 'Ketik nama resep, kategori, atau bahan untuk mencari',
          ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.borderOn(context),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 15,
              color: selected ? Colors.white : AppTheme.textSubOn(context)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSubOn(context),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ]),
      ),
    );
  }
}

class _CommunitySearchCard extends StatelessWidget {
  final CommunityRecipe recipe;
  final VoidCallback onTap;

  const _CommunitySearchCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: recipe.imageUrl.isNotEmpty
                  ? Image.network(
                      recipe.imageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  recipe.title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textOn(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  recipe.description,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSubOn(context)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      recipe.category,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 13, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    recipe.averageRating.toStringAsFixed(1),
                    style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context)),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      recipe.authorName,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSubOn(context)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        width: 72,
        height: 72,
        color: AppTheme.surfaceOn(context),
        child: const Icon(Icons.restaurant, size: 30, color: AppTheme.primary),
      );
}
