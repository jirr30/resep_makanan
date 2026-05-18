import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/recipe_card.dart';
import '../widgets/shimmer_card.dart';
import '../widgets/error_view.dart';
import 'detail_screen.dart';
import 'add_recipe_screen.dart';
import 'favorites_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'shopping_list_screen.dart';
import 'meal_planner_screen.dart';
import 'community_screen.dart';

enum SortOption { newest, ratingDesc, timeAsc, nameAsc }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  List<Recipe> _all = [];
  List<Recipe> _filtered = [];
  List<String> _customCategories = [];
  String _selectedCategory = 'Semua';
  SortOption _sort = SortOption.newest;
  Set<String> _difficultyFilter = {};
  int _maxTime = 999;
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
      final cats = await _db.getCustomCategories();
      final recipes = _selectedCategory == 'Semua'
          ? await _db.getAllRecipes()
          : await _db.getByCategory(_selectedCategory);
      if (mounted) {
        setState(() {
          _customCategories = cats;
          _all = recipes;
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
      case SortOption.newest:   break;
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
        onPressed: () async {
          await _db.insertRecipe(recipe);
          _load();
        },
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
        content: TextField(controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama kategori...'),
          textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _db.addCustomCategory(ctrl.text.trim()).then((_) {
                  if (context.mounted) Navigator.pop(context);
                });
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

  bool get _hasActiveFilter => _difficultyFilter.isNotEmpty || _maxTime < 999 || _sort != SortOption.newest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ResepKu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())).then((_) => _load())),
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.tune), onPressed: _showSortFilter, tooltip: 'Sort & Filter'),
              if (_hasActiveFilter) Positioned(right: 8, top: 8, child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
              )),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'settings':   Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                case 'shopping':   Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen()));
                case 'planner':    Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPlannerScreen()));
                case 'community':  Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityScreen()));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'community', child: Row(children: [Icon(Icons.people, size: 18), SizedBox(width: 8), Text('Komunitas')])),
              const PopupMenuItem(value: 'planner',   child: Row(children: [Icon(Icons.calendar_month, size: 18), SizedBox(width: 8), Text('Meal Planner')])),
              const PopupMenuItem(value: 'shopping',  child: Row(children: [Icon(Icons.shopping_cart, size: 18), SizedBox(width: 8), Text('Daftar Belanja')])),
              const PopupMenuItem(value: 'settings',  child: Row(children: [Icon(Icons.settings, size: 18), SizedBox(width: 8), Text('Pengaturan')])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBanner(),
          _buildCategories(),
          if (_hasActiveFilter) _buildActiveFilterChips(),
          Expanded(
            child: _hasError
                ? ErrorView(message: 'Gagal memuat resep.\nCoba lagi.', onRetry: _load)
                : _loading
                    ? const ShimmerList(count: 3)
                    : _filtered.isEmpty
                        ? EmptyView(
                            icon: Icons.no_food,
                            title: 'Tidak Ada Resep',
                            subtitle: _hasActiveFilter ? 'Coba ubah filter atau kategori' : 'Belum ada resep. Tambahkan resep pertamamu!',
                            actionLabel: _hasActiveFilter ? null : 'Tambah Resep',
                            onAction: _hasActiveFilter ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddRecipeScreen())).then((_) => _load()),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => Dismissible(
                                key: Key('recipe_${_filtered[i].id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                confirmDismiss: (_) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Hapus Resep?'),
                                      content: Text('Hapus "${_filtered[i].title}"?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (_) => _deleteWithUndo(_filtered[i]),
                                child: RecipeCard(
                                  recipe: _filtered[i],
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(recipe: _filtered[i]))).then((_) => _load()),
                                  onFavorite: () => _toggleFavorite(_filtered[i]),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddRecipeScreen())).then((_) => _load()),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Resep', style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())).then((_) => _load());
        },
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
            child: Text('${_filtered.length} Resep', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
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
            onLongPress: isCustom ? () async {
              final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                title: Text('Hapus kategori "$cat"?'),
                content: const Text('Resep dengan kategori ini tidak ikut terhapus.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                ],
              ));
              if (confirm == true) {
                await _db.deleteCustomCategory(cat);
                if (_selectedCategory == cat) setState(() => _selectedCategory = 'Semua');
                _load();
              }
            } : null,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppTheme.primary : Theme.of(context).dividerColor),
              ),
              alignment: Alignment.center,
              child: Text(cat, style: TextStyle(
                color: selected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(spacing: 6, children: [
        if (_sort != SortOption.newest) _filterChip(
          _sort == SortOption.ratingDesc ? 'Rating ↑' : _sort == SortOption.timeAsc ? 'Waktu ↑' : 'A–Z',
          onDelete: () { setState(() { _sort = SortOption.newest; _applyFilters(); }); },
        ),
        ..._difficultyFilter.map((d) => _filterChip(d,
          onDelete: () { setState(() { _difficultyFilter.remove(d); _applyFilters(); }); })),
        if (_maxTime < 999) _filterChip('≤$_maxTime mnt',
          onDelete: () { setState(() { _maxTime = 999; _applyFilters(); }); }),
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
    _maxTime = widget.maxTime >= 999 ? 180.0 : widget.maxTime.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Text('Sort & Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () { setState(() { _sort = SortOption.newest; _difficulty.clear(); _maxTime = 180; }); },
                child: const Text('Reset', style: TextStyle(color: AppTheme.primary)),
              ),
            ]),
          ),
          const Divider(),
          Expanded(
            child: ListView(controller: ctrl, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
              const Text('Urutkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                _sortChip('Terbaru', SortOption.newest),
                _sortChip('Rating ↑', SortOption.ratingDesc),
                _sortChip('Waktu ↑', SortOption.timeAsc),
                _sortChip('Nama A–Z', SortOption.nameAsc),
              ]),
              const SizedBox(height: 20),
              const Text('Kesulitan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: AppConstants.difficulties.map((d) => FilterChip(
                label: Text(d),
                selected: _difficulty.contains(d),
                selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                checkmarkColor: AppTheme.primary,
                onSelected: (v) => setState(() { v ? _difficulty.add(d) : _difficulty.remove(d); }),
              )).toList()),
              const SizedBox(height: 20),
              Row(children: [
                const Text('Waktu Maksimal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Text(
                  _maxTime >= 180 ? 'Semua' : '${_maxTime.round()} menit',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ]),
              Slider(
                value: _maxTime,
                min: 15, max: 180, divisions: 11,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _maxTime = v),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('15 mnt', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const Text('180 mnt+', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  widget.onApply(_sort, _difficulty, _maxTime >= 180 ? 999 : _maxTime.round());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Terapkan Filter', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ],
      ),
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
