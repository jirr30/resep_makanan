import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'add_recipe_screen.dart';
import 'auth_gate_screen.dart';
import 'community_detail_screen.dart';
import 'profile_screen.dart';
import 'user_profile_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Komunitas'),
        actions: [
          if (auth.isLoggedIn)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: auth.user?.photoURL != null
                      ? NetworkImage(auth.user!.photoURL!)
                      : null,
                  backgroundColor: AppTheme.primary,
                  child: auth.user?.photoURL == null
                      ? const Icon(Icons.person, size: 18, color: Colors.white)
                      : null,
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const AuthGateScreen(),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 350),
                ),
                (_) => false,
              ),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Login'),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Semua Resep'),
            Tab(text: 'Mengikuti'),
            Tab(text: 'Resep Saya'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AllRecipesTab(fs: _fs),
          auth.isLoggedIn
              ? _FollowingFeedTab(fs: _fs)
              : _LoginPrompt(onLogin: () => Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const AuthGateScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 350),
                  ),
                  (_) => false,
                )),
          auth.isLoggedIn
              ? _MyRecipesTab(fs: _fs)
              : _LoginPrompt(onLogin: () => Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const AuthGateScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 350),
                  ),
                  (_) => false,
                )),
        ],
      ),
    );
  }
}

// ─── All Recipes Tab (Search + Pagination) ────────────────────────────────────

class _AllRecipesTab extends StatefulWidget {
  final FirestoreService fs;
  const _AllRecipesTab({required this.fs});

  @override
  State<_AllRecipesTab> createState() => _AllRecipesTabState();
}

class _AllRecipesTabState extends State<_AllRecipesTab> {
  final _scrollCtrl    = ScrollController();
  final _searchCtrl    = TextEditingController();

  List<CommunityRecipe> _recipes     = [];
  List<CommunityRecipe> _searchPool  = [];  // semua resep untuk search
  String  _searchQuery    = '';
  String  _selectedCat    = 'Semua';
  bool    _isSearching    = false;
  bool    _loading        = true;
  bool    _loadingMore    = false;
  bool    _hasMore        = true;
  bool    _searchLoading  = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isSearching) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() { _loading = true; _error = null; _recipes = []; _hasMore = true; });
    try {
      final cat    = _selectedCat == 'Semua' ? null : _selectedCat;
      PagedResult result;
      try {
        result = await widget.fs.getRecipesPaged(category: cat);
      } catch (_) {
        // Fallback jika composite index belum aktif di Firestore:
        // load semua tanpa filter kategori, filter client-side.
        result = await widget.fs.getRecipesPaged();
      }
      if (mounted) {
        setState(() {
          _recipes = cat == null
              ? result.recipes
              : result.recipes.where((r) => r.category == cat).toList();
          _hasMore = result.hasMore;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _recipes.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final lastDoc = await widget.fs.getLastDocSnapshot(_recipes.last.id);
      final result  = await widget.fs.getRecipesPaged(
        startAfter: lastDoc,
        category: _selectedCat == 'Semua' ? null : _selectedCat,
      );
      if (mounted) {
        setState(() {
          _recipes.addAll(result.recipes);
          _hasMore     = result.hasMore;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _activateSearch(String query) async {
    setState(() { _isSearching = true; _searchQuery = query; });
    if (_searchPool.isEmpty) {
      setState(() => _searchLoading = true);
      try {
        final all = await widget.fs.getAllRecipesForSearch();
        if (mounted) setState(() { _searchPool = all; _searchLoading = false; });
      } catch (_) {
        if (mounted) setState(() => _searchLoading = false);
      }
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() { _isSearching = false; _searchQuery = ''; });
    _loadInitial();
  }

  // Saat search aktif: filter pool by query + kategori.
  // Saat tidak search: _recipes sudah difilter server-side, tampilkan langsung.
  List<CommunityRecipe> get _displayList {
    if (_isSearching) {
      return _searchPool.where((r) {
        final matchCat = _selectedCat == 'Semua' || r.category == _selectedCat;
        final q        = _searchQuery.toLowerCase();
        final matchQ   = r.title.toLowerCase().contains(q) ||
            r.authorName.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q) ||
            r.ingredients.any((ing) => ing.toLowerCase().contains(q));
        return matchCat && matchQ;
      }).toList();
    }
    return _recipes;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildSearchBar(),
      _buildCategoryChips(),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SearchBar(
        controller: _searchCtrl,
        hintText: 'Cari resep atau nama chef...',
        leading: Icon(Icons.search, color: AppTheme.textSubOn(context)),
        trailing: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSearch,
            ),
        ],
        onChanged: (v) {
          final q = v.trim();
          if (q.isNotEmpty) {
            _activateSearch(q);
          } else {
            _clearSearch();
          }
        },
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(AppTheme.surfaceOn(context)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.borderOn(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final cats = ['Semua', ...AppConstants.categories.where((c) => c != 'Semua')];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat      = cats[i];
          final selected = _selectedCat == cat;
          return FilterChip(
            label: Text(cat, style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : AppTheme.textSubOn(context),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            )),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedCat = cat);
              // Saat search aktif: cukup re-filter pool lewat _displayList.
              // Saat tidak search: reload dari Firestore dengan filter kategori.
              if (!_isSearching) _loadInitial();
            },
            backgroundColor: Colors.transparent,
            selectedColor: AppTheme.primary,
            checkmarkColor: Colors.white,
            side: BorderSide(color: selected ? AppTheme.primary : AppTheme.borderOn(context)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off, size: 48, color: AppTheme.textSubOn(context)),
        const SizedBox(height: 12),
        Text('Gagal memuat resep', style: TextStyle(color: AppTheme.textSubOn(context))),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _loadInitial, child: const Text('Coba Lagi')),
      ]));
    }
    if (_searchLoading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: AppTheme.primary),
        const SizedBox(height: 12),
        Text('Memuat semua resep untuk pencarian...', style: TextStyle(color: AppTheme.textSubOn(context))),
      ]));
    }

    final list = _displayList;
    if (list.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off, size: 64, color: AppTheme.textSubOn(context)),
        const SizedBox(height: 16),
        Text(
          _isSearching ? 'Tidak ada resep untuk "$_searchQuery"' : 'Belum ada resep dari komunitas',
          style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 15),
          textAlign: TextAlign.center,
        ),
        if (_isSearching) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: _clearSearch, child: const Text('Hapus pencarian')),
        ],
      ]));
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _isSearching ? null : _scrollCtrl,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: list.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == list.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            );
          }
          return _CommunityCard(recipe: list[i], fs: widget.fs);
        },
      ),
    );
  }
}

// ─── My Recipes Tab ──────────────────────────────────────────────────────────

class _MyRecipesTab extends StatefulWidget {
  final FirestoreService fs;
  const _MyRecipesTab({required this.fs});

  @override
  State<_MyRecipesTab> createState() => _MyRecipesTabState();
}

class _MyRecipesTabState extends State<_MyRecipesTab> {
  List<CommunityRecipe> _recipes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.fs.getMyRecipes();
      if (mounted) setState(() { _recipes = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFFFF8C55)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.restaurant_menu, size: 52, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum ada resep yang kamu bagikan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textOn(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Bagikan resepmu ke komunitas dan\ninspirasikan chef lainnya!',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSubOn(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
              ).then((_) => _load()),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Bagikan Resep Kamu',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _recipes.length,
        itemBuilder: (_, i) => _CommunityCard(
          recipe: _recipes[i],
          fs: widget.fs,
          showDelete: true,
          onDelete: () async {
            try {
              await widget.fs.deleteRecipe(_recipes[i].id);
              _load();
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gagal menghapus resep. Coba lagi.')),
                );
              }
            }
          },
        ),
      ),
    );
  }
}

// ─── Following Feed Tab ───────────────────────────────────────────────────────

class _FollowingFeedTab extends StatefulWidget {
  final FirestoreService fs;
  const _FollowingFeedTab({required this.fs});

  @override
  State<_FollowingFeedTab> createState() => _FollowingFeedTabState();
}

class _FollowingFeedTabState extends State<_FollowingFeedTab> {
  final _scrollCtrl = ScrollController();
  List<CommunityRecipe> _recipes     = [];
  bool    _loading     = true;
  bool    _loadingMore = false;
  bool    _hasMore     = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _recipes = []; _hasMore = true; });
    try {
      final result = await widget.fs.getFollowingFeed();
      if (mounted) {
        setState(() { _recipes = result.recipes; _hasMore = result.hasMore; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _recipes.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final lastDoc = await widget.fs.getLastDocSnapshot(_recipes.last.id);
      final result  = await widget.fs.getFollowingFeed(startAfter: lastDoc);
      if (mounted) {
        setState(() {
          _recipes.addAll(result.recipes);
          _hasMore     = result.hasMore;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off, size: 48, color: AppTheme.textSubOn(context)),
        const SizedBox(height: 12),
        Text('Gagal memuat', style: TextStyle(color: AppTheme.textSubOn(context))),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load, child: const Text('Coba Lagi')),
      ]));
    }
    if (_recipes.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline, size: 64, color: AppTheme.textSubOn(context)),
          const SizedBox(height: 16),
          Text('Belum ada resep dari chef yang kamu ikuti',
              style: TextStyle(fontSize: 15, color: AppTheme.textSubOn(context)),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Ikuti chef lain untuk melihat resep mereka di sini',
              style: TextStyle(fontSize: 13, color: AppTheme.textSubOn(context)),
              textAlign: TextAlign.center),
        ]),
      ));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _recipes.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _recipes.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            );
          }
          return _CommunityCard(recipe: _recipes[i], fs: widget.fs);
        },
      ),
    );
  }
}

// ─── Community Card ──────────────────────────────────────────────────────────

class _CommunityCard extends StatelessWidget {
  final CommunityRecipe recipe;
  final FirestoreService fs;
  final bool showDelete;
  final VoidCallback? onDelete;

  const _CommunityCard({
    required this.recipe,
    required this.fs,
    this.showDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(recipe: recipe),
        )),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: recipe.imageUrl.isNotEmpty
                ? Image.network(
                    recipe.imageUrl,
                    height: 160, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                GestureDetector(
                  onTap: () => _openAuthorProfile(context),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: recipe.authorPhoto.isNotEmpty
                          ? NetworkImage(recipe.authorPhoto)
                          : null,
                      backgroundColor: AppTheme.primary,
                      child: recipe.authorPhoto.isEmpty
                          ? const Icon(Icons.person, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(recipe.authorName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      if (recipe.publishedAt != null)
                        Text(DateFormat('d MMM yyyy', 'id_ID').format(recipe.publishedAt!),
                            style: TextStyle(fontSize: 11, color: AppTheme.textSubOn(context))),
                    ]),
                  ]),
                ),
                const Spacer(),
                if (showDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _confirmDelete(context),
                    tooltip: 'Hapus resep',
                  ),
              ]),
              const SizedBox(height: 8),
              Text(recipe.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(recipe.description,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSubOn(context)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Row(children: [
                _Chip(Icons.timer, '${recipe.cookingTime} mnt'),
                const SizedBox(width: 8),
                _Chip(Icons.bar_chart, recipe.difficulty),
                const SizedBox(width: 8),
                _Chip(Icons.category_outlined, recipe.category),
                const Spacer(),
                const Icon(Icons.favorite, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Text('${recipe.likes}',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
                const SizedBox(width: 10),
                Icon(Icons.comment_outlined, size: 14, color: AppTheme.textSubOn(context)),
                const SizedBox(width: 4),
                Text('${recipe.commentCount}',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
                const SizedBox(width: 10),
                Icon(Icons.remove_red_eye_outlined, size: 14, color: AppTheme.textSubOn(context)),
                const SizedBox(width: 4),
                Text(AppConstants.formatCount(recipe.viewCount),
                    style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  void _openAuthorProfile(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (recipe.authorId == myUid) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId:       recipe.authorId,
          initialName:  recipe.authorName,
          initialPhoto: recipe.authorPhoto,
        ),
      ));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Resep'),
        content: Text(
            'Hapus "${recipe.title}" dari komunitas?\nTindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) onDelete?.call();
  }

  Widget _imagePlaceholder() => Container(
    height: 160,
    color: AppTheme.primary.withValues(alpha: 0.15),
    child: const Center(child: Icon(Icons.restaurant, size: 48, color: AppTheme.primary)),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOn(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderOn(context)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: AppTheme.textSubOn(context)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSubOn(context))),
      ]),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  final VoidCallback onLogin;
  const _LoginPrompt({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_outline, size: 64, color: AppTheme.textSubOn(context)),
        const SizedBox(height: 16),
        Text('Login untuk melihat resep kamu',
            style: TextStyle(fontSize: 16, color: AppTheme.textSubOn(context))),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onLogin,
          icon: const Icon(Icons.login),
          label: const Text('Login Sekarang'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
        ),
      ]),
    ));
  }
}
