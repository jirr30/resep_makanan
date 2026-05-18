import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';

class CommunityDetailScreen extends StatefulWidget {
  final CommunityRecipe recipe;
  const CommunityDetailScreen({super.key, required this.recipe});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();
  final _db = DatabaseService();
  late TabController _tabController;

  bool _isLiked = false;
  bool _likeLoading = false;
  int _likes = 0;
  bool _isSaving = false;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  bool get _isOwner => _currentUserId != null && _currentUserId == widget.recipe.authorId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _likes = widget.recipe.likes;
    _loadLikeStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLikeStatus() async {
    if (_currentUserId == null) return;
    final liked = await _fs.isLiked(widget.recipe.id);
    if (mounted) setState(() => _isLiked = liked);
  }

  Future<void> _toggleLike() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login dulu untuk memberi like')),
      );
      return;
    }
    setState(() => _likeLoading = true);
    final newLiked = !_isLiked;
    try {
      await _fs.toggleLike(widget.recipe.id, newLiked);
      if (mounted) {
        setState(() {
          _isLiked = newLiked;
          _likes += newLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _saveToLocal() async {
    setState(() => _isSaving = true);
    try {
      await _db.insertRecipe(widget.recipe.toRecipe());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${widget.recipe.title}" disimpan ke koleksi kamu!'),
        backgroundColor: AppTheme.primary,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteFromCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus dari Komunitas?'),
        content: Text('"${widget.recipe.title}" akan dihapus dari komunitas dan tidak bisa dikembalikan.'),
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
    if (confirm != true) return;
    try {
      await _fs.deleteRecipe(widget.recipe.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resep dihapus dari komunitas')),
        );
        Navigator.pop(context, 'deleted');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus. Coba lagi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildAuthorInfo()),
          SliverToBoxAdapter(
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Bahan'),
                Tab(text: 'Cara Masak'),
                Tab(text: 'Nutrisi'),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildIngredients(),
                _buildSteps(),
                _buildNutrition(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppTheme.primary,
      actions: [
        // Like button — semua orang bisa like
        _likeLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              )
            : IconButton(
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red[200] : Colors.white),
                onPressed: _toggleLike,
                tooltip: _isLiked ? 'Batal like' : 'Like resep ini',
              ),
        // Hapus — hanya owner
        if (_isOwner)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _deleteFromCommunity,
            tooltip: 'Hapus dari komunitas',
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(fit: StackFit.expand, children: [
          Image.network(
            widget.recipe.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppTheme.primary.withValues(alpha: 0.3),
              child: const Icon(Icons.restaurant, size: 80, color: Colors.white54),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20)),
                child: Text(widget.recipe.category, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Text(widget.recipe.title,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black45)])),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.timer, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text('${widget.recipe.cookingTime} mnt', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 12),
                const Icon(Icons.people, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text('${widget.recipe.servings} porsi', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 12),
                const Icon(Icons.bar_chart, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(widget.recipe.difficulty, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                const Icon(Icons.favorite, color: Colors.red, size: 14),
                const SizedBox(width: 4),
                Text('$_likes', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildAuthorInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: widget.recipe.authorPhoto.isNotEmpty
              ? NetworkImage(widget.recipe.authorPhoto)
              : null,
          backgroundColor: AppTheme.primary,
          child: widget.recipe.authorPhoto.isEmpty
              ? const Icon(Icons.person, color: Colors.white, size: 20)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(widget.recipe.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (_isOwner) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                child: const Text('Kamu', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
          if (widget.recipe.publishedAt != null)
            Text(
              'Dibagikan ${DateFormat('d MMM yyyy', 'id_ID').format(widget.recipe.publishedAt!)}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
        ])),
      ]),
    );
  }

  Widget _buildIngredients() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.recipe.ingredients.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.recipe.ingredients[i], style: const TextStyle(fontSize: 15))),
        ]),
      ),
    );
  }

  Widget _buildSteps() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.recipe.steps.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primary,
            child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(widget.recipe.steps[i], style: const TextStyle(fontSize: 15, height: 1.5)),
          )),
        ]),
      ),
    );
  }

  Widget _buildNutrition() {
    if (widget.recipe.calories == 0 && widget.recipe.protein == 0 && widget.recipe.carbs == 0 && widget.recipe.fat == 0) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.info_outline, size: 48, color: AppTheme.textSecondary),
        SizedBox(height: 12),
        Text('Informasi nutrisi tidak tersedia', style: TextStyle(color: AppTheme.textSecondary)),
      ]));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _NutritionCard('Kalori', '${widget.recipe.calories}', 'kkal', Icons.local_fire_department, Colors.orange),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _NutritionCard('Protein', widget.recipe.protein.toString(), 'g', Icons.egg, Colors.blue)),
          const SizedBox(width: 12),
          Expanded(child: _NutritionCard('Karbo', widget.recipe.carbs.toString(), 'g', Icons.grain, Colors.amber)),
          const SizedBox(width: 12),
          Expanded(child: _NutritionCard('Lemak', widget.recipe.fat.toString(), 'g', Icons.opacity, Colors.red)),
        ]),
      ]),
    );
  }

  Widget _buildBottomBar() {
    if (_isOwner) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _deleteFromCommunity,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Hapus dari Komunitas', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          // Like button
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _isLiked ? Colors.red : AppTheme.primary.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : AppTheme.primary),
              onPressed: _likeLoading ? null : _toggleLike,
            ),
          ),
          const SizedBox(width: 12),
          // Simpan ke koleksi
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveToLocal,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bookmark_add_outlined),
              label: Text(_isSaving ? 'Menyimpan...' : 'Simpan ke Koleksi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _NutritionCard(this.label, this.value, this.unit, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(unit, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ]),
    );
  }
}
