import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/shimmer_card.dart';
import '../widgets/error_view.dart';
import 'auth_gate_screen.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();
  late final TabController _tabController;

  // Community carousels (Untuk Kamu tab)
  bool _loadingCommunity = true;
  bool _firestoreLoaded = false;
  List<CommunityRecipe> _trendingCommunity = [];
  List<CommunityRecipe> _latestCommunity = [];

  // Terbaru feed (tab 2 — paginated Firestore)
  String _selectedCategory = 'Semua';
  List<CommunityRecipe> _terbaruFeed = [];
  List<CommunityRecipe> _terbaruFiltered = [];
  DocumentSnapshot? _lastTerbaruDoc;
  bool _loadingTerbaru = true;
  bool _loadingMoreTerbaru = false;
  bool _hasMoreTerbaru = true;
  bool _terbaruError = false;

  // Following feed (tab 1)
  List<CommunityRecipe> _followingFeed = [];
  DocumentSnapshot? _lastFollowingDoc;
  bool _loadingFollowing = false;
  bool _loadingMoreFollowing = false;
  bool _hasMoreFollowing = true;
  bool _followingLoaded = false;
  bool _followingError = false;

  // Sort & filter (Terbaru tab)
  SortOption _sort = SortOption.newest;
  Set<String> _difficultyFilter = {};
  int _maxTime = 999;

  int _bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1 && !_followingLoaded) {
      _loadFollowingPage(reset: true);
    }
  }

  // ── Loading ───────────────────────────────────────────────────────────────────

  Future<void> _load({bool forceFirestore = false}) async {
    if (forceFirestore || !_firestoreLoaded) {
      await Future.wait([_loadCommunity(), _loadTerbaruPage(reset: true)]);
    } else {
      await _loadTerbaruPage(reset: true);
    }
    if (_followingLoaded) {
      _loadFollowingPage(reset: true);
    }
  }

  Future<void> _loadCommunity() async {
    if (mounted) setState(() => _loadingCommunity = true);
    try {
      final trending  = await _fs.getTrendingRecipes().catchError((_) => <CommunityRecipe>[]);
      final latestRaw = await _fs.getLatestCommunityRecipes().catchError((_) => <CommunityRecipe>[]);
      final trendingIds = trending.map((r) => r.id).toSet();
      final latest      = latestRaw.where((r) => !trendingIds.contains(r.id)).toList();
      if (mounted) {
        setState(() {
          _trendingCommunity = trending;
          _latestCommunity   = latest;
          _loadingCommunity  = false;
          _firestoreLoaded   = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loadingCommunity = false; _firestoreLoaded = true; });
    }
  }

  Future<void> _loadTerbaruPage({bool reset = false}) async {
    if (!reset && (_loadingMoreTerbaru || !_hasMoreTerbaru)) return;
    if (reset) {
      if (mounted) {
        setState(() {
          _loadingTerbaru = true;
          _terbaruError   = false;
          _terbaruFeed    = [];
          _lastTerbaruDoc = null;
          _hasMoreTerbaru = true;
        });
      }
    } else {
      if (mounted) setState(() => _loadingMoreTerbaru = true);
    }
    try {
      final cat    = _selectedCategory == 'Semua' ? null : _selectedCategory;
      final result = await _fs.getRecipesPaged(
        startAfter: reset ? null : _lastTerbaruDoc,
        category: cat,
      );
      if (mounted) {
        setState(() {
          if (reset) {
            _terbaruFeed = result.recipes;
          } else {
            _terbaruFeed.addAll(result.recipes);
          }
          _lastTerbaruDoc     = result.lastDoc;
          _hasMoreTerbaru     = result.hasMore;
          _loadingTerbaru     = false;
          _loadingMoreTerbaru = false;
          _applyTerbaruFilters();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingTerbaru     = false;
          _loadingMoreTerbaru = false;
          if (reset) _terbaruError = true;
        });
      }
    }
  }

  void _applyTerbaruFilters() {
    var list = List<CommunityRecipe>.from(_terbaruFeed);
    if (_difficultyFilter.isNotEmpty) {
      list = list.where((r) => _difficultyFilter.contains(r.difficulty)).toList();
    }
    if (_maxTime < 999) {
      list = list.where((r) => r.cookingTime <= _maxTime).toList();
    }
    switch (_sort) {
      case SortOption.newest:     break;
      case SortOption.ratingDesc: list.sort((a, b) => b.averageRating.compareTo(a.averageRating));
      case SortOption.timeAsc:    list.sort((a, b) => a.cookingTime.compareTo(b.cookingTime));
      case SortOption.nameAsc:    list.sort((a, b) => a.title.compareTo(b.title));
    }
    _terbaruFiltered = list;
  }

  Future<void> _loadFollowingPage({bool reset = false}) async {
    if (!reset && (_loadingMoreFollowing || !_hasMoreFollowing)) return;
    if (reset) {
      if (mounted) {
        setState(() {
          _loadingFollowing = true;
          _followingError   = false;
          _followingFeed    = [];
          _lastFollowingDoc = null;
          _hasMoreFollowing = true;
          _followingLoaded  = true;
        });
      }
    } else {
      if (mounted) setState(() => _loadingMoreFollowing = true);
    }
    try {
      final result = await _fs.getFollowingFeed(
          startAfter: reset ? null : _lastFollowingDoc);
      if (mounted) {
        setState(() {
          if (reset) {
            _followingFeed = result.recipes;
          } else {
            _followingFeed.addAll(result.recipes);
          }
          _lastFollowingDoc     = result.lastDoc;
          _hasMoreFollowing     = result.hasMore;
          _loadingFollowing     = false;
          _loadingMoreFollowing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingFollowing     = false;
          _loadingMoreFollowing = false;
          if (reset) _followingError = true;
        });
      }
    }
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
          setState(() {
            _sort             = sort;
            _difficultyFilter = diff;
            _maxTime          = maxTime;
            _applyTerbaruFilters();
          });
        },
      ),
    );
  }

  bool get _hasActiveFilter =>
      _difficultyFilter.isNotEmpty || _maxTime < 999 || _sort != SortOption.newest;

  void _onBottomNavTap(int index) {
    if (index == 0) {
      setState(() => _bottomNavIndex = 0);
      return;
    }
    setState(() => _bottomNavIndex = index);
    Widget screen;
    switch (index) {
      case 1: screen = const CommunityScreen();  break;
      case 2: screen = const FavoritesScreen();  break;
      case 3: screen = const ProfileScreen();    break;
      default: return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) {
          setState(() => _bottomNavIndex = 0);
          if (index == 1) _load(forceFirestore: true);
        });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _AppDrawer(onRefresh: () => _load(forceFirestore: true)),
      appBar: AppBar(
        title: const Text('ResepKu',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Cari resep',
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifikasi',
            onPressed: () => _showNotificationPanel(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Untuk Kamu'),
            Tab(text: 'Mengikuti'),
            Tab(text: 'Terbaru'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUntukKamu(),
          _buildMengikuti(),
          _buildTerbaru(),
        ],
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

  // ── Tab 0: Untuk Kamu ─────────────────────────────────────────────────────────

  Widget _buildUntukKamu() {
    return RefreshIndicator(
      onRefresh: () => _load(forceFirestore: true),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildGreetingHeader()),
          SliverToBoxAdapter(child: _buildSearchBar()),

          if (_loadingCommunity) ...[
            SliverToBoxAdapter(child: _buildCarouselShimmer(
                'Populer di Komunitas', Icons.local_fire_department, Colors.orange)),
            SliverToBoxAdapter(child: _buildCarouselShimmer(
                'Terbaru dari Komunitas', Icons.public, Colors.teal)),
          ] else ...[
            if (_trendingCommunity.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildCommunityCarousel(
                  title: 'Populer di Komunitas',
                  icon: Icons.local_fire_department,
                  iconColor: Colors.orange,
                  recipes: _trendingCommunity,
                  onViewAll: () => _tabController.animateTo(2),
                ),
              ),
            if (_latestCommunity.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildCommunityCarousel(
                  title: 'Terbaru dari Komunitas',
                  icon: Icons.public,
                  iconColor: Colors.teal,
                  recipes: _latestCommunity,
                  onViewAll: () => _tabController.animateTo(2),
                ),
              ),
          ],

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(2),
                icon: const Icon(Icons.explore_outlined, color: AppTheme.primary),
                label: const Text('Jelajahi Semua Resep',
                    style: TextStyle(color: AppTheme.primary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  // ── Tab 1: Mengikuti ──────────────────────────────────────────────────────────

  Widget _buildMengikuti() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline, size: 40,
                  color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Masuk untuk melihat feed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: AppTheme.textOn(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ikuti chef favoritmu dan lihat\nresep terbaru mereka di sini',
              style: TextStyle(fontSize: 13, color: AppTheme.textSubOn(context),
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AuthGateScreen())),
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Masuk / Daftar',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll is ScrollEndNotification &&
            scroll.metrics.extentAfter < 300 &&
            !_loadingMoreFollowing &&
            _hasMoreFollowing &&
            !_loadingFollowing) {
          _loadFollowingPage();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => _loadFollowingPage(reset: true),
        child: !_followingLoaded
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : _loadingFollowing
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _followingError
                    ? ErrorView(
                        message: 'Gagal memuat feed.\nCoba lagi.',
                        onRetry: () => _loadFollowingPage(reset: true),
                      )
                    : _followingFeed.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: 400,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.people_outline,
                                              size: 64,
                                              color: AppTheme.textSubOn(context)),
                                          const SizedBox(height: 16),
                                          Text('Belum ada postingan',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.textOn(context))),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Ikuti chef lain untuk melihat\nresep terbaru mereka di sini',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.textSubOn(context),
                                                height: 1.5),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 24),
                                          OutlinedButton.icon(
                                            onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const CommunityScreen())),
                                            icon: const Icon(Icons.explore,
                                                color: AppTheme.primary),
                                            label: const Text('Temukan Chef',
                                                style: TextStyle(
                                                    color: AppTheme.primary)),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                  color: AppTheme.primary),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ]),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: _followingFeed.length +
                                (_loadingMoreFollowing ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == _followingFeed.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        color: AppTheme.primary, strokeWidth: 2),
                                  ),
                                );
                              }
                              return _CommunityFeedCard(
                                recipe: _followingFeed[i],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommunityDetailScreen(
                                        recipe: _followingFeed[i]),
                                  ),
                                ).then((_) => _loadFollowingPage(reset: true)),
                              );
                            },
                          ),
      ),
    );
  }

  // ── Tab 2: Terbaru ────────────────────────────────────────────────────────────

  Widget _buildTerbaru() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll is ScrollEndNotification &&
            scroll.metrics.extentAfter < 300 &&
            !_loadingMoreTerbaru &&
            _hasMoreTerbaru &&
            !_loadingTerbaru) {
          _loadTerbaruPage();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => _loadTerbaruPage(reset: true),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildCategoryChips()),
            if (_hasActiveFilter)
              SliverToBoxAdapter(child: _buildActiveFilterChips()),
            SliverToBoxAdapter(child: _buildTerbaruHeader()),

            if (_terbaruError)
              SliverFillRemaining(
                child: ErrorView(
                  message: 'Gagal memuat resep komunitas.\nCoba lagi.',
                  onRetry: () => _loadTerbaruPage(reset: true),
                ),
              )
            else if (_loadingTerbaru)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => const ShimmerCard(),
                  childCount: 6,
                ),
              )
            else if (_terbaruFiltered.isEmpty)
              SliverFillRemaining(
                child: EmptyView(
                  icon: Icons.public_off,
                  title: 'Belum Ada Resep',
                  subtitle: _hasActiveFilter
                      ? 'Coba ubah filter atau kategori'
                      : 'Belum ada resep di komunitas.',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _CommunityFeedCard(
                    recipe: _terbaruFiltered[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CommunityDetailScreen(recipe: _terbaruFiltered[i]),
                      ),
                    ).then((_) => _load(forceFirestore: true)),
                  ),
                  childCount: _terbaruFiltered.length,
                ),
              ),

            if (_loadingMoreTerbaru)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2),
                  ),
                ),
              )
            else if (!_hasMoreTerbaru && _terbaruFiltered.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Semua ${_terbaruFiltered.length} resep sudah ditampilkan',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSubOn(context)),
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ── Greeting Header ───────────────────────────────────────────────────────────

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
            Text('$greeting, $firstName! 👋',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
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

  // ── Search Bar ────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ),
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
                offset: const Offset(0, 2)),
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

  // ── Category Chips (Terbaru tab) ──────────────────────────────────────────────

  Widget _buildCategoryChips() {
    final cats = ['Semua', ...AppConstants.categories];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: cats.length,
          itemBuilder: (_, i) {
            final cat      = cats[i];
            final selected = cat == _selectedCategory;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = cat);
                _loadTerbaruPage(reset: true);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : Colors.transparent,
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
              setState(() {
                _sort = SortOption.newest;
                _applyTerbaruFilters();
              });
            },
          ),
        ..._difficultyFilter.map((d) => _filterChip(d, onDelete: () {
              setState(() {
                _difficultyFilter.remove(d);
                _applyTerbaruFilters();
              });
            })),
        if (_maxTime < 999)
          _filterChip('≤$_maxTime mnt', onDelete: () {
            setState(() {
              _maxTime = 999;
              _applyTerbaruFilters();
            });
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

  Widget _buildTerbaruHeader() {
    final label =
        _selectedCategory == 'Semua' ? 'Resep Komunitas' : _selectedCategory;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(children: [
        const Icon(Icons.public, size: 18, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textOn(context))),
        const SizedBox(width: 8),
        if (!_loadingTerbaru && _terbaruFiltered.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_terbaruFiltered.length}${_hasMoreTerbaru ? '+' : ''}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold),
            ),
          ),
        const Spacer(),
        Stack(children: [
          IconButton(
            icon: const Icon(Icons.tune, size: 20),
            onPressed: _showSortFilter,
            tooltip: 'Sort & Filter',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          if (_hasActiveFilter)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Colors.amber, shape: BoxShape.circle),
              ),
            ),
        ]),
      ]),
    );
  }

  // ── Carousel Shimmer ──────────────────────────────────────────────────────────

  Widget _buildCarouselShimmer(String title, IconData icon, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textOn(context))),
          ]),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 4,
            itemBuilder: (_, __) => const ShimmerCarouselCard(),
          ),
        ),
      ],
    );
  }

  // ── Community Carousel ────────────────────────────────────────────────────────

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
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textOn(context))),
            const Spacer(),
            if (onViewAll != null)
              GestureDetector(
                onTap: onViewAll,
                child: const Text('Lihat Semua',
                    style: TextStyle(fontSize: 13, color: AppTheme.primary)),
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
                          builder: (_) =>
                              CommunityDetailScreen(recipe: recipes[i])))
                  .then((_) => _load(forceFirestore: true)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Notification Panel ────────────────────────────────────────────────────────

  void _showNotificationPanel(BuildContext outerCtx) {
    final future = _fs.getActivityNotifications();
    showModalBottomSheet(
      context: outerCtx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.borderOn(context),
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Icon(Icons.notifications, color: AppTheme.primary),
              SizedBox(width: 10),
              Text('Aktivitas Komunitas',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<AppNotification>>(
              future: future,
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.notifications_none,
                          size: 56, color: AppTheme.textSubOn(context)),
                      const SizedBox(height: 12),
                      Text('Belum ada aktivitas komunitas',
                          style: TextStyle(
                              color: AppTheme.textSubOn(context),
                              fontSize: 14)),
                    ]),
                  );
                }
                return ListView.separated(
                  controller: ctrl,
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72, endIndent: 16),
                  itemBuilder: (_, i) => _RealNotifTile(
                    notif: items[i],
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      if (items[i].recipe != null) {
                        Navigator.push(
                          outerCtx,
                          MaterialPageRoute(
                            builder: (_) => CommunityDetailScreen(
                                recipe: items[i].recipe!),
                          ),
                        ).then((_) => _load(forceFirestore: true));
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Community Feed Card ───────────────────────────────────────────────────────

class _CommunityFeedCard extends StatelessWidget {
  final CommunityRecipe recipe;
  final VoidCallback onTap;
  const _CommunityFeedCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: recipe.imageUrl.isNotEmpty
                  ? Image.network(recipe.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(recipe.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  CircleAvatar(
                    radius: 9,
                    backgroundImage: recipe.authorPhoto.isNotEmpty
                        ? NetworkImage(recipe.authorPhoto)
                        : null,
                    backgroundColor:
                        AppTheme.primary.withValues(alpha: 0.2),
                    child: recipe.authorPhoto.isEmpty
                        ? const Icon(Icons.person,
                            size: 11, color: AppTheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(recipe.authorName,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSubOn(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 10, children: [
                  _meta(Icons.favorite, Colors.red, '${recipe.likes}',
                      context),
                  _meta(
                      Icons.star,
                      Colors.amber,
                      recipe.averageRating > 0
                          ? recipe.averageRating.toStringAsFixed(1)
                          : '-',
                      context),
                  _meta(
                      Icons.remove_red_eye_outlined,
                      Colors.blueGrey,
                      AppConstants.formatCount(recipe.viewCount),
                      context),
                  _meta(Icons.timer_outlined, AppTheme.primary,
                      '${recipe.cookingTime} mnt', context),
                  if (recipe.category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(recipe.category,
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.primary)),
                    ),
                ]),
                if (recipe.publishedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d MMM yyyy', 'id_ID')
                        .format(recipe.publishedAt!),
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSubOn(context)),
                  ),
                ],
              ]),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppTheme.textSubOn(context)),
          ]),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, Color color, String text, BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 2),
      Text(text,
          style: TextStyle(
              fontSize: 11, color: AppTheme.textSubOn(context))),
    ]);
  }

  Widget _placeholder() => Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.restaurant, color: AppTheme.primary),
      );
}

// ── Notification Tile ─────────────────────────────────────────────────────────

String _formatTimeAgo(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
  if (diff.inDays < 1) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return '${time.day}/${time.month}/${time.year}';
}

class _RealNotifTile extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  const _RealNotifTile({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: notif.imageUrl.isNotEmpty
            ? Image.network(notif.imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder())
            : _placeholder(),
      ),
      title: Text(notif.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 2),
        Text(notif.body,
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(_formatTimeAgo(notif.time),
            style: TextStyle(
                fontSize: 11, color: AppTheme.textSubOn(context))),
      ]),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }

  Widget _placeholder() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            const Icon(Icons.restaurant, color: AppTheme.primary, size: 24),
      );
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
                  style: TextStyle(color: Colors.red))),
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
    final user  = FirebaseAuth.instance.currentUser;
    final theme = context.watch<ThemeProvider>();
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
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
              Text(user?.displayName ?? 'Pengguna',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(user?.email ?? '',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Profil Saya',
                    onTap: () => _go(context, const ProfileScreen())),
                _DrawerItem(
                    icon: Icons.people_outline,
                    label: 'Komunitas',
                    onTap: () => _go(context, const CommunityScreen())),
                _DrawerItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Meal Planner',
                    onTap: () =>
                        _go(context, const MealPlannerScreen())),
                _DrawerItem(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Daftar Belanja',
                    onTap: () =>
                        _go(context, const ShoppingListScreen())),
                _DrawerItem(
                    icon: Icons.favorite_outline,
                    label: 'Favorit',
                    onTap: () => _go(context, const FavoritesScreen(),
                        refresh: true)),
                const Divider(indent: 20, endIndent: 20),
                _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Pengaturan',
                    onTap: () => _go(context, const SettingsScreen())),
              ],
            ),
          ),
          const Divider(height: 1),
          Row(children: [
            Expanded(
              child: _DrawerItem(
                icon: Icons.logout,
                label: 'Keluar',
                color: Colors.red,
                onTap: () => _signOut(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: Icon(
                  theme.isDark ? Icons.dark_mode : Icons.light_mode,
                  color: AppTheme.primary,
                ),
                tooltip: theme.isDark ? 'Mode Terang' : 'Mode Gelap',
                onPressed: theme.toggle,
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ── Drawer Item ───────────────────────────────────────────────────────────────

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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
            child: recipe.imageUrl.isNotEmpty
                ? Image.network(recipe.imageUrl,
                    height: 95,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(context))
                : _placeholder(context),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(recipe.title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textOn(context)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(recipe.authorName,
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.textSubOn(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.favorite, size: 11, color: Colors.red),
                const SizedBox(width: 2),
                Text('${recipe.likes}',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSubOn(context))),
                const SizedBox(width: 6),
                const Icon(Icons.star, size: 11, color: Colors.amber),
                const SizedBox(width: 2),
                Text(
                  recipe.averageRating > 0
                      ? recipe.averageRating.toStringAsFixed(1)
                      : '-',
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.textSubOn(context)),
                ),
              ]),
            ]),
          ),
        ]),
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

// ── Sort & Filter Sheet ───────────────────────────────────────────────────────

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
    _sort       = widget.currentSort;
    _difficulty = Set.from(widget.difficultyFilter);
    _maxTime = widget.maxTime >= 999 ? 180.0 : widget.maxTime.toDouble();
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
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: AppTheme.borderOn(context),
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Text('Sort & Filter',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                _sortChip('Terbaru',  SortOption.newest),
                _sortChip('Rating ↑', SortOption.ratingDesc),
                _sortChip('Waktu ↑',  SortOption.timeAsc),
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
                min: 15,
                max: 180,
                divisions: 11,
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
                    padding: const EdgeInsets.symmetric(vertical: 14)),
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
