import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/recipe_card.dart';
import '../widgets/shimmer_card.dart';
import '../widgets/error_view.dart';
import 'auth_gate_screen.dart';
import 'detail_screen.dart';
import 'add_recipe_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'shopping_list_screen.dart';
import 'meal_planner_screen.dart';
import 'community_detail_screen.dart';
import 'community_screen.dart';

enum SortOption { newest, ratingDesc, timeAsc, nameAsc }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  final _fs = FirestoreService();
  List<Recipe> _all = [];
  List<Recipe> _filtered = [];
  List<String> _customCategories = [];
  String _selectedCategory = 'Semua';
  SortOption _sort = SortOption.newest;
  Set<String> _difficultyFilter = {};
  int _maxTime = 999;
  bool _loading = true;
  bool _hasError = false;
  int _favCount = 0;
  List<Recipe> _allRecipes = [];
  List<Recipe> _recentRecipes = [];
  List<Recipe> _favoriteRecipes = [];
  List<CommunityRecipe> _trendingCommunity = [];
  List<CommunityRecipe> _latestCommunity = [];
  int _communityCount = 0;
  int _bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      // Mulai fetch Firestore & SQLite secara paralel
      final trendingFuture = _fs.getTrendingRecipes()
          .catchError((_) => <CommunityRecipe>[]);
      final latestFuture = _fs.getLatestCommunityRecipes()
          .catchError((_) => <CommunityRecipe>[]);
      final countFuture = _fs.getCommunityRecipeCount()
          .catchError((_) => 0);

      final cats = await _db.getCustomCategories();
      final all  = await _db.getAllRecipes();
      final recipes = _selectedCategory == 'Semua'
          ? all
          : await _db.getByCategory(_selectedCategory);

      final favorites = all.where((r) => r.isFavorite).toList();
      final recent    = (List<Recipe>.from(all)
            ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0)))
          .take(5)
          .toList();
      // Tunggu hasil Firestore (sudah jalan paralel)
      final trending = await trendingFuture;
      final latestRaw = await latestFuture;
      final count    = await countFuture;

      // Buang resep yang sudah tampil di trending agar tidak duplikat
      final trendingIds = trending.map((r) => r.id).toSet();
      final latest = latestRaw.where((r) => !trendingIds.contains(r.id)).toList();

      if (mounted) {
        setState(() {
          _customCategories  = cats;
          _allRecipes        = all;
          _all               = recipes;
          _favCount          = favorites.length;
          _recentRecipes     = recent;
          _favoriteRecipes   = favorites;
          _trendingCommunity = trending;
          _latestCommunity   = latest;
          _communityCount    = count;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  void _applyFilters() {
    var list = List<Recipe>.from(_all);
    if (_difficultyFilter.isNotEmpty) {
      list = list.where((r) => _difficultyFilter.contains(r.difficulty)).toList();
    }
    if (_maxTime < 999) {
      list = list.where((r) => r.cookingTime <= _maxTime).toList();
    }
    switch (_sort) {
      case SortOption.newest:     break;
      case SortOption.ratingDesc: list.sort((a, b) => b.rating.compareTo(a.rating));
      case SortOption.timeAsc:    list.sort((a, b) => a.cookingTime.compareTo(b.cookingTime));
      case SortOption.nameAsc:    list.sort((a, b) => a.title.compareTo(b.title));
    }
    _filtered = list;
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    await _db.toggleFavorite(recipe.id!, !recipe.isFavorite);
    _load();
  }

  Future<void> _deleteWithUndo(Recipe recipe) async {
    await _db.deleteRecipe(recipe.id!);
    _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${recipe.title}" dihapus'),
      action: SnackBarAction(
        label: 'Batalkan',
        textColor: Colors.amber,
        onPressed: () async { await _db.insertRecipe(recipe); _load(); },
      ),
      duration: const Duration(seconds: 5),
    ));
  }

  void _showSortFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SortFilterSheet(
        currentSort: _sort,
        difficultyFilter: _difficultyFilter,
        maxTime: _maxTime,
        onApply: (sort, diff, maxTime) {
          setState(() { _sort = sort; _difficultyFilter = diff; _maxTime = maxTime; _applyFilters(); });
        },
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Kategori Baru'),
        content: TextField(
          controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama kategori...'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                final nav = Navigator.of(context);
                await _db.addCustomCategory(ctrl.text.trim());
                nav.pop();
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    _load();
  }

  List<String> get _allCategories =>
      [...AppConstants.categories, ..._customCategories.where((c) => !AppConstants.categories.contains(c))];

  bool get _hasActiveFilter =>
      _difficultyFilter.isNotEmpty || _maxTime < 999 || _sort != SortOption.newest;

  void _onBottomNavTap(int index) {
    if (index == 0) {
      setState(() => _bottomNavIndex = 0);
      return;
    }
    // Push as new screen, stay "on" beranda in bottom nav
    Widget screen;
    switch (index) {
      case 1: screen = const CommunityScreen();  break;
      case 2: screen = const FavoritesScreen();  break;
      case 3: screen = const ProfileScreen();    break;
      default: return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _AppDrawer(onRefresh: _load),
      appBar: AppBar(
        title: const Text('ResepKu',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cari resep',
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SearchScreen()),
            ).then((_) => _load()),
          ),
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: _showSortFilter,
              tooltip: 'Sort & Filter',
            ),
            if (_hasActiveFilter)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.amber, shape: BoxShape.circle),
                ),
              ),
          ]),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifikasi',
            onPressed: () => _showNotificationPanel(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildGreetingHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildQuickStats()),
            if (!_loading && _trendingCommunity.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildCommunityCarousel(
                  title: 'Populer di Komunitas',
                  icon: Icons.local_fire_department,
                  iconColor: Colors.orange,
                  recipes: _trendingCommunity,
                  onViewAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CommunityScreen()),
                  ).then((_) => _load()),
                ),
              ),
            if (!_loading && _latestCommunity.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildCommunityCarousel(
                  title: 'Terbaru dari Komunitas',
                  icon: Icons.public,
                  iconColor: Colors.teal,
                  recipes: _latestCommunity,
                  onViewAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CommunityScreen()),
                  ).then((_) => _load()),
                ),
              ),
            if (!_loading && _recentRecipes.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildCarousel(
                  title: 'Terakhir Ditambahkan',
                  icon: Icons.access_time_outlined,
                  recipes: _recentRecipes,
                ),
              ),
            if (!_loading && _favoriteRecipes.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildCarousel(
                  title: 'Favorit Kamu',
                  icon: Icons.favorite_outline,
                  iconColor: Colors.red,
                  recipes: _favoriteRecipes,
                  onViewAll: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  ).then((_) => _load()),
                ),
              ),
            SliverToBoxAdapter(child: _buildCategories()),
            if (_hasActiveFilter) SliverToBoxAdapter(child: _buildActiveFilterChips()),
            SliverToBoxAdapter(child: _buildSectionHeader()),
            if (_hasError)
              SliverFillRemaining(
                child: ErrorView(message: 'Gagal memuat resep.\nCoba lagi.', onRetry: _load),
              )
            else if (_loading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const ShimmerCard(),
                  childCount: 4,
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                child: EmptyView(
                  icon: Icons.no_food,
                  title: 'Tidak Ada Resep',
                  subtitle: _hasActiveFilter
                      ? 'Coba ubah filter atau kategori'
                      : 'Belum ada resep.\nTambahkan resep pertamamu!',
                  actionLabel: _hasActiveFilter ? null : 'Tambah Resep',
                  onAction: _hasActiveFilter
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
                          ).then((_) => _load()),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Dismissible(
                    key: Key('recipe_${_filtered[i].id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.red, borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async => showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Hapus Resep?'),
                        content: Text('Hapus "${_filtered[i].title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) => _deleteWithUndo(_filtered[i]),
                    child: RecipeCard(
                      recipe: _filtered[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetailScreen(recipe: _filtered[i])),
                      ).then((_) => _load()),
                      onFavorite: () => _toggleFavorite(_filtered[i]),
                    ),
                  ),
                  childCount: _filtered.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
        ).then((_) => _load()),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Resep',
            style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: _onBottomNavTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSubOn(context),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Komunitas'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              activeIcon: Icon(Icons.favorite),
              label: 'Favorit'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
    );
  }

  // ── Greeting Header ────────────────────────────────────────────────────────

  Widget _buildGreetingHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Selamat Pagi'
        : hour < 15
            ? 'Selamat Siang'
            : hour < 18
                ? 'Selamat Sore'
                : 'Selamat Malam';
    final firstName = (user?.displayName ?? 'Pengguna').split(' ').first;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFFFF8C55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '$greeting, $firstName! 👋',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mau masak apa\nhari ini?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.3),
            ),
          ]),
        ),
        CircleAvatar(
          radius: 30,
          backgroundImage:
              user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
          backgroundColor: Colors.white.withValues(alpha: 0.3),
          child: user?.photoURL == null
              ? const Icon(Icons.person, size: 30, color: Colors.white)
              : null,
        ),
      ]),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ).then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          Icon(Icons.search, color: AppTheme.textSubOn(context), size: 20),
          const SizedBox(width: 10),
          Text(
            'Cari resep, bahan, atau kategori...',
            style: TextStyle(
                color: AppTheme.textSubOn(context).withValues(alpha: 0.8),
                fontSize: 14),
          ),
        ]),
      ),
    );
  }

  // ── Quick Stats ────────────────────────────────────────────────────────────

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        _StatCard(
          icon: Icons.menu_book_outlined,
          value: _loading ? '-' : '${_allRecipes.length}',
          label: 'Total Resep',
          color: AppTheme.primary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.favorite_outline,
          value: _loading ? '-' : '$_favCount',
          label: 'Favorit',
          color: Colors.red,
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.public,
          value: _loading ? '-' : '$_communityCount',
          label: 'Komunitas',
          color: Colors.teal,
        ),
      ]),
    );
  }

  // ── Category Chips ─────────────────────────────────────────────────────────

  Widget _buildCategories() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _allCategories.length + 1,
          itemBuilder: (_, i) {
            if (i == _allCategories.length) {
              return GestureDetector(
                onTap: _showAddCategoryDialog,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary),
                  ),
                  child: const Row(children: [
                    Icon(Icons.add, size: 16, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text('Kategori',
                        style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                  ]),
                ),
              );
            }
            final cat = _allCategories[i];
            final selected = cat == _selectedCategory;
            final isCustom = !AppConstants.categories.contains(cat);
            return GestureDetector(
              onTap: () { setState(() => _selectedCategory = cat); _load(); },
              onLongPress: isCustom
                  ? () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('Hapus kategori "$cat"?'),
                          content: const Text(
                              'Resep dengan kategori ini tidak ikut terhapus.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Hapus',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _db.deleteCustomCategory(cat);
                        if (_selectedCategory == cat) {
                          setState(() => _selectedCategory = 'Semua');
                        }
                        _load();
                      }
                    }
                  : null,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color:
                      selected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: selected
                          ? AppTheme.primary
                          : Theme.of(context).dividerColor),
                ),
                alignment: Alignment.center,
                child: Text(
                  cat,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(spacing: 6, children: [
        if (_sort != SortOption.newest)
          _filterChip(
            _sort == SortOption.ratingDesc
                ? 'Rating ↑'
                : _sort == SortOption.timeAsc
                    ? 'Waktu ↑'
                    : 'A–Z',
            onDelete: () {
              setState(() { _sort = SortOption.newest; _applyFilters(); });
            },
          ),
        ..._difficultyFilter.map((d) => _filterChip(d,
            onDelete: () {
              setState(() { _difficultyFilter.remove(d); _applyFilters(); });
            })),
        if (_maxTime < 999)
          _filterChip('≤$_maxTime mnt',
              onDelete: () {
                setState(() { _maxTime = 999; _applyFilters(); });
              }),
      ]),
    );
  }

  Widget _filterChip(String label, {required VoidCallback onDelete}) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onDelete,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // ── Community Carousel ────────────────────────────────────────────────────

  Widget _buildCommunityCarousel({
    required String title,
    required IconData icon,
    required List<CommunityRecipe> recipes,
    Color? iconColor,
    VoidCallback? onViewAll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Icon(icon, size: 18, color: iconColor ?? AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textOn(context),
              ),
            ),
            const Spacer(),
            if (onViewAll != null)
              GestureDetector(
                onTap: onViewAll,
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(fontSize: 13, color: AppTheme.primary),
                ),
              ),
          ]),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recipes.length,
            itemBuilder: (_, i) => _CommunityCarouselCard(
              recipe: recipes[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CommunityDetailScreen(recipe: recipes[i])),
              ).then((_) => _load()),
            ),
          ),
        ),
      ],
    );
  }

  // ── Section Header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(children: [
        Text(
          _selectedCategory == 'Semua' ? 'Semua Resep' : _selectedCategory,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.textOn(context),
          ),
        ),
        const SizedBox(width: 8),
        if (!_loading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_filtered.length}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ]),
    );
  }

  // ── Carousel ──────────────────────────────────────────────────────────────

  Widget _buildCarousel({
    required String title,
    required IconData icon,
    required List<Recipe> recipes,
    Color? iconColor,
    VoidCallback? onViewAll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Icon(icon, size: 18, color: iconColor ?? AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textOn(context),
              ),
            ),
            const Spacer(),
            if (onViewAll != null)
              GestureDetector(
                onTap: onViewAll,
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(fontSize: 13, color: AppTheme.primary),
                ),
              ),
          ]),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recipes.length,
            itemBuilder: (_, i) => _CarouselCard(
              recipe: recipes[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => DetailScreen(recipe: recipes[i])),
              ).then((_) => _load()),
            ),
          ),
        ),
      ],
    );
  }

  void _showNotificationPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Icon(Icons.notifications, color: AppTheme.primary),
              SizedBox(width: 10),
              Text('Notifikasi',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          const Divider(),
          Expanded(
            child: ListView(controller: ctrl, children: const [
              _NotifTile(
                icon: Icons.restaurant_menu,
                color: AppTheme.primary,
                title: 'Selamat datang di ResepKu!',
                body: 'Mulai tambahkan resep favoritmu dan bagikan ke komunitas.',
                time: 'Baru saja',
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Stat Card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textSubOn(context)),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Notification Tile ─────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  const _NotifTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 2),
        Text(body, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        Text(time,
            style: TextStyle(
                fontSize: 11, color: AppTheme.textSubOn(context))),
      ]),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
}

// ── App Drawer ────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final VoidCallback onRefresh;
  const _AppDrawer({required this.onRefresh});

  void _go(BuildContext context, Widget screen, {bool refresh = false}) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => screen))
        .then((_) { if (refresh) onRefresh(); });
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final nav = Navigator.of(context);
    nav.pop();
    await context.read<AuthProvider>().signOut();
    if (context.mounted) {
      nav.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthGateScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, Color(0xFFFF9A6C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                child: user?.photoURL == null
                    ? const Icon(Icons.person, size: 36, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                user?.displayName ?? 'Pengguna',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                user?.email ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.person_outline,
                  label: 'Profil Saya',
                  onTap: () => _go(context, const ProfileScreen()),
                ),
                _DrawerItem(
                  icon: Icons.people_outline,
                  label: 'Komunitas',
                  onTap: () => _go(context, const CommunityScreen()),
                ),
                _DrawerItem(
                  icon: Icons.calendar_month_outlined,
                  label: 'Meal Planner',
                  onTap: () => _go(context, const MealPlannerScreen()),
                ),
                _DrawerItem(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Daftar Belanja',
                  onTap: () => _go(context, const ShoppingListScreen()),
                ),
                _DrawerItem(
                  icon: Icons.favorite_outline,
                  label: 'Favorit',
                  onTap: () =>
                      _go(context, const FavoritesScreen(), refresh: true),
                ),
                const Divider(indent: 20, endIndent: 20),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Pengaturan',
                  onTap: () => _go(context, const SettingsScreen()),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _DrawerItem(
            icon: Icons.logout,
            label: 'Keluar',
            color: Colors.red,
            onTap: () => _signOut(context),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, color: c)),
      onTap: onTap,
      horizontalTitleGap: 8,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

// ── Community Carousel Card ───────────────────────────────────────────────────

class _CommunityCarouselCard extends StatelessWidget {
  final CommunityRecipe recipe;
  final VoidCallback onTap;
  const _CommunityCarouselCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.cardOn(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderOn(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: recipe.imageUrl.isNotEmpty
                  ? Image.network(
                      recipe.imageUrl,
                      height: 95,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textOn(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.authorName,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSubOn(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.favorite, size: 11, color: Colors.red),
                    const SizedBox(width: 2),
                    Text(
                      '${recipe.likes}',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSubOn(context)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.star, size: 11, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      recipe.averageRating > 0
                          ? recipe.averageRating.toStringAsFixed(1)
                          : '-',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSubOn(context)),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        height: 95,
        color: AppTheme.primary.withValues(alpha: 0.12),
        child: const Center(
            child: Icon(Icons.restaurant, color: AppTheme.primary, size: 28)),
      );
}

// ── Carousel Card ─────────────────────────────────────────────────────────────

class _CarouselCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  const _CarouselCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.cardOn(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderOn(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 90,
                width: double.infinity,
                child: _buildImage(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textOn(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.star, size: 11, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      recipe.userRating > 0
                          ? recipe.userRating.toStringAsFixed(1)
                          : recipe.rating.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSubOn(context)),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.timer_outlined,
                        size: 11, color: AppTheme.textSubOn(context)),
                    const SizedBox(width: 2),
                    Text(
                      '${recipe.cookingTime}m',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSubOn(context)),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (recipe.imagePath != null) {
      final file = File(recipe.imagePath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover, width: double.infinity);
      }
    }
    if (recipe.imageUrl.isNotEmpty) {
      return Image.network(
        recipe.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) => Container(
        color: AppTheme.surfaceOn(context),
        child: const Center(
            child: Icon(Icons.restaurant, color: AppTheme.primary, size: 28)),
      );
}

// ── Sort & Filter Bottom Sheet ────────────────────────────────────────────────

class _SortFilterSheet extends StatefulWidget {
  final SortOption currentSort;
  final Set<String> difficultyFilter;
  final int maxTime;
  final void Function(SortOption, Set<String>, int) onApply;

  const _SortFilterSheet({
    required this.currentSort,
    required this.difficultyFilter,
    required this.maxTime,
    required this.onApply,
  });

  @override
  State<_SortFilterSheet> createState() => _SortFilterSheetState();
}

class _SortFilterSheetState extends State<_SortFilterSheet> {
  late SortOption _sort;
  late Set<String> _difficulty;
  late double _maxTime;

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    _difficulty = Set.from(widget.difficultyFilter);
    _maxTime =
        widget.maxTime >= 999 ? 180.0 : widget.maxTime.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Text('Sort & Filter',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  _sort = SortOption.newest;
                  _difficulty.clear();
                  _maxTime = 180;
                });
              },
              child: const Text('Reset',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          ]),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const Text('Urutkan',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                _sortChip('Terbaru', SortOption.newest),
                _sortChip('Rating ↑', SortOption.ratingDesc),
                _sortChip('Waktu ↑', SortOption.timeAsc),
                _sortChip('Nama A–Z', SortOption.nameAsc),
              ]),
              const SizedBox(height: 20),
              const Text('Kesulitan',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: AppConstants.difficulties
                    .map((d) => FilterChip(
                          label: Text(d),
                          selected: _difficulty.contains(d),
                          selectedColor:
                              AppTheme.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppTheme.primary,
                          onSelected: (v) => setState(() {
                            v
                                ? _difficulty.add(d)
                                : _difficulty.remove(d);
                          }),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Row(children: [
                const Text('Waktu Maksimal',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Text(
                  _maxTime >= 180
                      ? 'Semua'
                      : '${_maxTime.round()} menit',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold),
                ),
              ]),
              Slider(
                value: _maxTime,
                min: 15, max: 180, divisions: 11,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _maxTime = v),
              ),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('15 mnt',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSubOn(context))),
                    Text('180 mnt+',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSubOn(context))),
                  ]),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  widget.onApply(_sort, _difficulty,
                      _maxTime >= 180 ? 999 : _maxTime.round());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Terapkan Filter',
                    style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _sortChip(String label, SortOption option) {
    return ChoiceChip(
      label: Text(label),
      selected: _sort == option,
      selectedColor: AppTheme.primary.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.primary,
      onSelected: (_) => setState(() => _sort = option),
    );
  }
}
