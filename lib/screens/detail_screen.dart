import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/nutrition_service.dart';
import '../utils/app_theme.dart';
import 'edit_recipe_screen.dart';
import 'cooking_mode_screen.dart';
import 'shopping_list_screen.dart';

class DetailScreen extends StatefulWidget {
  final Recipe recipe;
  const DetailScreen({super.key, required this.recipe});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

// Scales a number in an ingredient string by [factor].
String _scaleIngredient(String ingredient, double factor) {
  if (factor == 1.0) return ingredient;
  return ingredient.replaceAllMapped(
    RegExp(r'(\d+(?:[.,]\d+)?)'),
    (m) {
      final value = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      if (value == null) return m.group(1)!;
      final scaled = value * factor;
      return scaled == scaled.roundToDouble() ? scaled.toInt().toString() : scaled.toStringAsFixed(1);
    },
  );
}

class _DetailScreenState extends State<DetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Recipe _recipe;
  final _db = DatabaseService();
  final _notif = NotificationService();
  int _servings = 0;
  bool _calculatingNutrition = false;

  int get _currentServings => _servings == 0 ? _recipe.servings : _servings;
  double get _scaleFactor => _currentServings / _recipe.servings;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    await _db.toggleFavorite(_recipe.id!, !_recipe.isFavorite);
    if (!mounted) return;
    setState(() => _recipe = _recipe.copyWith(isFavorite: !_recipe.isFavorite));
  }

  Future<void> _rateRecipe(double rating) async {
    await _db.updateUserRating(_recipe.id!, rating);
    if (!mounted) return;
    setState(() => _recipe = _recipe.copyWith(userRating: rating));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rating $rating bintang disimpan!'), backgroundColor: AppTheme.primary),
    );
  }

  void _shareRecipe() {
    final text = '''
Resep: ${_recipe.title}
Kategori: ${_recipe.category}
Waktu: ${_recipe.cookingTime} menit | Porsi: ${_recipe.servings}

Bahan-bahan:
${_recipe.ingredients.map((i) => '• $i').join('\n')}

Langkah-langkah:
${_recipe.steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Dibagikan dari aplikasi ResepKu
''';
    Share.share(text, subject: 'Resep ${_recipe.title}');
  }

  void _openCookingMode() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CookingModeScreen(recipe: _recipe)));
  }

  void _openTimer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimerSheet(recipe: _recipe, notif: _notif),
    );
  }

  Future<void> _addToShoppingList() async {
    await _db.addIngredientsToShoppingList(_recipe);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_recipe.ingredients.length} bahan ditambahkan ke daftar belanja!'),
      backgroundColor: AppTheme.primary,
      action: SnackBarAction(
        label: 'Lihat',
        textColor: Colors.amber,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen())),
      ),
    ));
  }

  Future<void> _shareToCommunity() async {
    // Jika sudah pernah dibagikan, tanya apakah ingin bagikan ulang
    if (_recipe.firestoreId != null) {
      final again = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sudah Dibagikan'),
          content: const Text(
              'Resep ini sudah ada di komunitas. Ingin membagikan ulang sebagai resep baru?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Bagikan Lagi')),
          ],
        ),
      );
      if (again != true) return;
    }

    try {
      final docId = await FirestoreService().publishRecipe(_recipe);
      if (!mounted) return;
      if (docId != null) {
        // Simpan firestoreId ke SQLite supaya status "sudah dibagikan" tersimpan
        final updated = _recipe.copyWith(firestoreId: docId);
        await _db.updateRecipe(updated);
        if (mounted) setState(() => _recipe = updated);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Resep berhasil dibagikan ke komunitas!'),
        backgroundColor: AppTheme.primary,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membagikan: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _calculateAndSaveNutrition() async {
    setState(() => _calculatingNutrition = true);
    try {
      final result = await NutritionService().estimateFromIngredients(
        ingredients: _recipe.ingredients,
        servings: _recipe.servings,
      );
      if (!mounted) return;
      final updated = _recipe.copyWith(
        calories: result.calories,
        protein: result.protein,
        carbs: result.carbs,
        fat: result.fat,
      );
      await _db.updateRecipe(updated);
      if (mounted) {
        setState(() => _recipe = updated);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nutrisi berhasil dihitung!'),
          backgroundColor: AppTheme.primary,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghitung nutrisi. Periksa koneksi dan coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _calculatingNutrition = false);
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(builder: (_) => EditRecipeScreen(recipe: _recipe)),
    );
    if (updated != null) setState(() => _recipe = updated);
  }

  Future<void> _deleteRecipe() async {
    if (_recipe.firestoreId != null) {
      final action = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Hapus Resep?'),
          content: Text('"${_recipe.title}" juga dibagikan di komunitas. Hapus dari mana?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            TextButton(
              onPressed: () => Navigator.pop(context, 'local'),
              child: const Text('Koleksi Saja'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, 'both'),
              child: const Text('Semua'),
            ),
          ],
        ),
      );
      if (action == null) return;
      await _db.deleteRecipe(_recipe.id!);
      if (action == 'both') {
        try { await FirestoreService().deleteRecipe(_recipe.firestoreId!); } catch (_) {}
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Hapus Resep?'),
          content: Text('Resep "${_recipe.title}" akan dihapus permanen.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await _db.deleteRecipe(_recipe.id!);
    }
    if (mounted) Navigator.pop(context, 'deleted');
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalImage = _recipe.imagePath != null && File(_recipe.imagePath!).existsSync();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            backgroundColor: AppTheme.primary,
            actions: [
              IconButton(
                icon: Icon(_recipe.isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: _toggleFavorite,
                tooltip: _recipe.isFavorite ? 'Hapus favorit' : 'Tambah favorit',
              ),
              IconButton(icon: const Icon(Icons.share), onPressed: _shareRecipe, tooltip: 'Bagikan'),
              if (_recipe.isOwned)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') _openEdit();
                    if (value == 'delete') _deleteRecipe();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Edit Resep'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Hapus Resep', style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: hasLocalImage
                  ? Image.file(File(_recipe.imagePath!), fit: BoxFit.cover)
                  : _recipe.imageUrl.isNotEmpty
                      ? Image.network(_recipe.imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder())
                      : _imagePlaceholder(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_recipe.category, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(_recipe.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                  const SizedBox(height: 10),
                  Text(_recipe.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textOn(context))),
                  const SizedBox(height: 8),
                  Text(_recipe.description, style: TextStyle(fontSize: 15, color: AppTheme.textSubOn(context), height: 1.5)),
                  const SizedBox(height: 16),
                  Row(children: [
                    _StatCard(icon: Icons.timer, value: '${_recipe.cookingTime}', unit: 'menit'),
                    const SizedBox(width: 12),
                    _StatCard(icon: Icons.people, value: '${_recipe.servings}', unit: 'porsi'),
                    const SizedBox(width: 12),
                    _StatCard(icon: Icons.bar_chart, value: _recipe.difficulty, unit: 'tingkat'),
                  ]),
                  const SizedBox(height: 16),
                  _buildServingScaler(),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(
                      onPressed: _openCookingMode,
                      icon: const Icon(Icons.play_circle),
                      label: const Text('Mode Memasak'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _openTimer,
                      icon: const Icon(Icons.timer),
                      label: const Text('Timer'),
                    )),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addToShoppingList,
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('Tambah ke Daftar Belanja'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_recipe.isOwned)
                    _buildShareCommunityButton()
                  else
                    _buildSavedFromCommunityBadge(),
                  const SizedBox(height: 16),
                  _buildRatingSection(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSubOn(context),
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Bahan'),
                Tab(text: 'Cara Masak'),
                Tab(text: 'Nutrisi'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildIngredients(), _buildSteps(), _buildNutrition()],
        ),
      ),
    );
  }

  Widget _buildSavedFromCommunityBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.public, size: 18, color: Colors.teal),
        const SizedBox(width: 10),
        Text(
          'Disimpan dari Komunitas',
          style: TextStyle(
            color: Colors.teal[700],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ]),
    );
  }

  Widget _buildShareCommunityButton() {
    final isPublished = _recipe.firestoreId != null;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _shareToCommunity,
        icon: Icon(
          isPublished ? Icons.check_circle : Icons.people_alt_outlined,
          color: isPublished ? Colors.green : AppTheme.primary,
        ),
        label: Text(
          isPublished ? 'Sudah Dibagikan ke Komunitas' : 'Bagikan ke Komunitas',
          style: TextStyle(color: isPublished ? Colors.green : AppTheme.primary),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isPublished ? Colors.green : AppTheme.primary),
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rating Pribadi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Row(children: [
            RatingBar.builder(
              initialRating: _recipe.userRating,
              minRating: 1,
              itemSize: 32,
              itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: _rateRecipe,
            ),
            const SizedBox(width: 12),
            Text(
              _recipe.userRating == 0 ? 'Belum dirating' : '${_recipe.userRating.toStringAsFixed(1)} / 5.0',
              style: TextStyle(color: AppTheme.textSubOn(context)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildServingScaler() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.people, color: AppTheme.primary, size: 20),
        const SizedBox(width: 8),
        const Text('Porsi:', style: TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          onPressed: _currentServings > 1 ? () => setState(() => _servings = _currentServings - 1) : null,
          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primary),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('$_currentServings', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          onPressed: () => setState(() => _servings = _currentServings + 1),
          icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
        if (_servings != 0) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _servings = 0),
            child: const Text('Reset', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  Widget _buildIngredients() {
    final scale = _scaleFactor;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recipe.ingredients.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(_scaleIngredient(_recipe.ingredients[i], scale), style: const TextStyle(fontSize: 15))),
        ]),
      ),
    );
  }

  Widget _buildSteps() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recipe.steps.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_recipe.steps[i], style: const TextStyle(fontSize: 15, height: 1.5)),
          )),
        ]),
      ),
    );
  }

  Widget _buildNutrition() {
    final hasData = _recipe.calories > 0 || _recipe.protein > 0 || _recipe.carbs > 0 || _recipe.fat > 0;
    if (!hasData) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.no_food, size: 60, color: AppTheme.textSubOn(context)),
          const SizedBox(height: 12),
          Text('Informasi nutrisi belum tersedia', style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 15)),
          const SizedBox(height: 4),
          Text('Hitung otomatis menggunakan AI dari bahan resep', style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 12)),
          const SizedBox(height: 20),
          _calculatingNutrition
              ? Column(children: [
                  const CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 12),
                  Text('Menghitung nutrisi dengan AI...', style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13)),
                ])
              : ElevatedButton.icon(
                  onPressed: _calculateAndSaveNutrition,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Hitung Nutrisi Otomatis'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Per porsi', style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13)),
          const SizedBox(height: 16),
          _NutritionRow(label: 'Kalori', value: '${_recipe.calories} kkal', icon: Icons.local_fire_department, color: Colors.orange),
          _NutritionRow(label: 'Protein', value: '${_recipe.protein.toStringAsFixed(1)} g', icon: Icons.egg, color: Colors.blue),
          _NutritionRow(label: 'Karbohidrat', value: '${_recipe.carbs.toStringAsFixed(1)} g', icon: Icons.grain, color: Colors.green),
          _NutritionRow(label: 'Lemak', value: '${_recipe.fat.toStringAsFixed(1)} g', icon: Icons.opacity, color: Colors.red),
          const SizedBox(height: 20),
          if (_recipe.calories > 0) _buildMacroBar(),
        ],
      ),
    );
  }

  Widget _buildMacroBar() {
    final total = (_recipe.protein * 4) + (_recipe.carbs * 4) + (_recipe.fat * 9);
    if (total == 0) return const SizedBox();
    final pProt = (_recipe.protein * 4) / total;
    final pCarb = (_recipe.carbs * 4) / total;
    final pFat  = (_recipe.fat * 9) / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Distribusi Makronutrisi', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(children: [
            Flexible(flex: (pProt * 100).round(), child: Container(height: 20, color: Colors.blue)),
            Flexible(flex: (pCarb * 100).round(), child: Container(height: 20, color: Colors.green)),
            Flexible(flex: (pFat * 100).round(), child: Container(height: 20, color: Colors.red)),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _MacroLegend(color: Colors.blue, label: 'Protein ${(pProt * 100).round()}%'),
          const SizedBox(width: 16),
          _MacroLegend(color: Colors.green, label: 'Karbo ${(pCarb * 100).round()}%'),
          const SizedBox(width: 16),
          _MacroLegend(color: Colors.red, label: 'Lemak ${(pFat * 100).round()}%'),
        ]),
      ],
    );
  }

  Widget _imagePlaceholder() => Container(
    color: AppTheme.primary.withValues(alpha: 0.3),
    child: const Icon(Icons.restaurant, size: 80, color: Colors.white),
  );
}

// ── Timer Bottom Sheet ───────────────────────────────────────────────────────

class _TimerSheet extends StatefulWidget {
  final Recipe recipe;
  final NotificationService notif;
  const _TimerSheet({required this.recipe, required this.notif});

  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  late int _totalSeconds;
  late int _remaining;
  Timer? _timer;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.recipe.cookingTime * 60;
    _remaining = _totalSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPause() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remaining <= 0) {
          _timer?.cancel();
          setState(() => _running = false);
          widget.notif.showTimerDone(widget.recipe.title);
        } else {
          setState(() => _remaining--);
        }
      });
      setState(() => _running = true);
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() { _remaining = _totalSeconds; _running = false; });
  }

  String _format(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds > 0 ? _remaining / _totalSeconds : 0.0;
    final isDone = _remaining == 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardOn(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderOn(context), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Timer: ${widget.recipe.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 180, height: 180,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                backgroundColor: AppTheme.surfaceOn(context),
                color: isDone ? Colors.green : AppTheme.primary,
              ),
            ),
            Column(children: [
              Text(_format(_remaining), style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: AppTheme.textOn(context))),
              Text(isDone ? 'Selesai!' : (_running ? 'Sedang berjalan' : 'Dijeda'), style: TextStyle(color: isDone ? Colors.green : AppTheme.textSubOn(context))),
            ]),
          ]),
          const SizedBox(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, size: 32),
              color: AppTheme.textSubOn(context),
            ),
            const SizedBox(width: 24),
            ElevatedButton.icon(
              onPressed: isDone ? null : _startPause,
              icon: Icon(_running ? Icons.pause : Icons.play_arrow),
              label: Text(_running ? 'Jeda' : 'Mulai'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  const _StatCard({required this.icon, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textOn(context))),
          Text(unit, style: TextStyle(fontSize: 11, color: AppTheme.textSubOn(context))),
        ]),
      ),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _NutritionRow({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(fontSize: 15)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
    );
  }
}

class _MacroLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _MacroLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
    ]);
  }
}
