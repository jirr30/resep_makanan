import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'auth_gate_screen.dart';
import 'edit_recipe_screen.dart';
import 'profile_screen.dart';
import 'user_profile_screen.dart';

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

  bool _isLiked       = false;
  bool _likeLoading   = false;
  int  _likes         = 0;
  bool _isSaving      = false;
  bool _isSaved       = false;

  double _userRating    = 0.0;
  bool   _ratingLoading = false;
  double _averageRating = 0.0;
  int    _ratingCount   = 0;
  int    _viewCount     = 0;
  int    _commentCount  = 0;

  bool? _isFollowing;    // null = belum dimuat
  bool  _followLoading = false;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  bool get _isOwner => _currentUserId != null && _currentUserId == widget.recipe.authorId;

  @override
  void initState() {
    super.initState();
    _tabController  = TabController(length: 4, vsync: this);
    _likes          = widget.recipe.likes;
    _averageRating  = widget.recipe.averageRating;
    _ratingCount    = widget.recipe.ratingCount;
    _viewCount      = widget.recipe.viewCount;
    _commentCount   = widget.recipe.commentCount;
    _loadLikeStatus();
    _loadUserRating();
    _countView();
    _loadFollowStatus();
    _checkIfSaved();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _countView() async {
    // Jangan hitung view milik sendiri
    if (_isOwner) return;
    // Harus login untuk bisa update Firestore (sesuai security rules)
    if (_currentUserId == null) return;
    try {
      await _fs.incrementViewCount(widget.recipe.id);
      if (mounted) setState(() => _viewCount++);
    } catch (_) {
      // View count bukan fitur kritis, abaikan jika gagal
    }
  }

  Future<void> _loadFollowStatus() async {
    if (_currentUserId == null || _isOwner) return;
    try {
      final following = await _fs.isFollowing(widget.recipe.authorId);
      if (mounted) setState(() => _isFollowing = following);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _isOwner || _isFollowing == null) return;
    setState(() => _followLoading = true);
    final wasFollowing = _isFollowing!;
    try {
      if (wasFollowing) {
        await _fs.unfollowUser(widget.recipe.authorId);
      } else {
        await _fs.followUser(widget.recipe.authorId);
      }
      if (mounted) setState(() => _isFollowing = !wasFollowing);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _checkIfSaved() async {
    final saved = await _db.isCommunityRecipeSaved(widget.recipe.id);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _loadLikeStatus() async {
    if (_currentUserId == null) return;
    final liked = await _fs.isLiked(widget.recipe.id);
    if (mounted) setState(() => _isLiked = liked);
  }

  Future<void> _loadUserRating() async {
    if (_currentUserId == null || _isOwner) return;
    final rating = await _fs.getUserRating(widget.recipe.id);
    if (mounted) setState(() => _userRating = rating);
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
          _likes  += newLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _submitRating(double rating) async {
    if (_isOwner || _currentUserId == null) return;
    setState(() => _ratingLoading = true);
    try {
      await _fs.rateRecipe(widget.recipe.id, rating);

      // Hitung rata-rata lokal sementara sambil Firestore update
      final prevUserRating = _userRating;
      double newAvg;
      int newCount;
      if (prevUserRating == 0.0) {
        newCount = _ratingCount + 1;
        newAvg   = _ratingCount == 0
            ? rating
            : ((_averageRating * _ratingCount) + rating) / newCount;
      } else {
        newCount = _ratingCount > 0 ? _ratingCount : 1;
        newAvg   = newCount <= 1
            ? rating
            : ((_averageRating * _ratingCount) - prevUserRating + rating) / newCount;
      }

      if (mounted) {
        setState(() {
          _userRating    = rating;
          _averageRating = newAvg;
          _ratingCount   = newCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rating ${rating.toStringAsFixed(0)} bintang tersimpan!'),
          backgroundColor: AppTheme.primary,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan rating. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _ratingLoading = false);
    }
  }

  Future<void> _saveToLocal() async {
    setState(() => _isSaving = true);
    try {
      final alreadySaved = await _db.isCommunityRecipeSaved(widget.recipe.id);
      if (!mounted) return;
      if (alreadySaved) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Resep ini sudah ada di koleksi kamu.'),
        ));
        setState(() { _isSaving = false; _isSaved = true; });
        return;
      }
      // Simpan dengan firestoreId agar bisa dicek ulang dan di-sync nanti
      final recipeToSave = widget.recipe.toRecipe().copyWith(
        firestoreId: widget.recipe.id,
      );
      await _db.insertRecipe(recipeToSave);
      if (!mounted) return;
      setState(() => _isSaved = true);
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

  Future<void> _editRecipe() async {
    // Cari salinan lokal terlebih dahulu agar id SQLite tersedia
    Recipe? local = await _db.getRecipeByFirestoreId(widget.recipe.id);
    final recipeToEdit = local ??
        widget.recipe.toRecipe().copyWith(firestoreId: widget.recipe.id);
    if (!mounted) return;
    await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(builder: (_) => EditRecipeScreen(recipe: recipeToEdit)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(innerBoxIsScrolled),
          SliverToBoxAdapter(child: _buildAuthorInfo()),
          SliverToBoxAdapter(child: _buildRatingSection()),
          SliverToBoxAdapter(
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              indicatorColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSubOn(context),
              tabs: [
                const Tab(text: 'Bahan'),
                const Tab(text: 'Cara Masak'),
                const Tab(text: 'Nutrisi'),
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Komentar'),
                    if (_commentCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_commentCount',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildIngredients(),
            _buildSteps(),
            _buildNutrition(),
            _buildComments(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar(bool forceElevated) {
    return SliverAppBar(
      expandedHeight: 260,
      forceElevated: forceElevated,
      pinned: true,
      backgroundColor: AppTheme.primary,
      actions: [
        _likeLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              )
            : IconButton(
                icon: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red[200] : Colors.white,
                ),
                onPressed: _toggleLike,
                tooltip: _isLiked ? 'Batal like' : 'Like resep ini',
              ),
        if (_isOwner) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: _editRecipe,
            tooltip: 'Edit resep',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _deleteFromCommunity,
            tooltip: 'Hapus dari komunitas',
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(fit: StackFit.expand, children: [
          widget.recipe.imageUrl.isNotEmpty
              ? Image.network(
                  widget.recipe.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    child: const Icon(Icons.restaurant, size: 80, color: Colors.white54),
                  ),
                )
              : Container(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  child: const Icon(Icons.restaurant, size: 80, color: Colors.white54),
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
            bottom: 16, left: 16, right: 16,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20)),
                child: Text(widget.recipe.category,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Text(widget.recipe.title,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                  )),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.timer, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text('${widget.recipe.cookingTime} mnt',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 12),
                const Icon(Icons.people, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text('${widget.recipe.servings} porsi',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 12),
                const Icon(Icons.bar_chart, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(widget.recipe.difficulty,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                const Icon(Icons.star, color: Colors.amber, size: 14),
                const SizedBox(width: 4),
                Text(
                  _ratingCount > 0 ? _averageRating.toStringAsFixed(1) : '-',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.favorite, color: Colors.red, size: 14),
                const SizedBox(width: 4),
                Text('$_likes', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 10),
                const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(AppConstants.formatCount(_viewCount),
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  void _openAuthorProfile() {
    final myUid = _currentUserId;
    if (widget.recipe.authorId == myUid) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId:       widget.recipe.authorId,
          initialName:  widget.recipe.authorName,
          initialPhoto: widget.recipe.authorPhoto,
        ),
      ));
    }
  }

  Widget _buildAuthorInfo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        GestureDetector(
          onTap: _openAuthorProfile,
          child: CircleAvatar(
            radius: 20,
            backgroundImage: widget.recipe.authorPhoto.isNotEmpty
                ? NetworkImage(widget.recipe.authorPhoto)
                : null,
            backgroundColor: AppTheme.primary,
            child: widget.recipe.authorPhoto.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 20)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: GestureDetector(
          onTap: _openAuthorProfile,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(widget.recipe.authorName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (_isOwner) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Kamu',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
            if (widget.recipe.publishedAt != null)
              Text(
                'Dibagikan ${DateFormat('d MMM yyyy', 'id_ID').format(widget.recipe.publishedAt!)}',
                style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 12),
              ),
            Row(children: [
              Icon(Icons.remove_red_eye_outlined,
                  size: 12, color: AppTheme.textSubOn(context)),
              const SizedBox(width: 4),
              Text('${AppConstants.formatCount(_viewCount)} kali dilihat',
                  style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 12)),
            ]),
          ]),
        )),
        // Follow / Unfollow button
        if (!_isOwner && _currentUserId != null && _isFollowing != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _followLoading
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                : _isFollowing!
                    ? OutlinedButton(
                        onPressed: _toggleFollow,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: AppTheme.primary),
                          foregroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Mengikuti',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      )
                    : ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Ikuti',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
          ),
      ]),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Tampilan rata-rata rating komunitas
        Row(children: [
          Row(children: List.generate(5, (i) => Icon(
            i < _averageRating.round() ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 20,
          ))),
          const SizedBox(width: 8),
          Text(
            _ratingCount > 0
                ? '${_averageRating.toStringAsFixed(1)} dari 5'
                : 'Belum ada rating',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (_ratingCount > 0) ...[
            const SizedBox(width: 6),
            Text('($_ratingCount ulasan)',
                style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13)),
          ],
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),

        // Aksi rating user
        if (_isOwner)
          Row(children: [
            Icon(Icons.info_outline, size: 16, color: AppTheme.textSubOn(context)),
            const SizedBox(width: 6),
            Text('Kamu tidak bisa menilai resep sendiri',
                style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13)),
          ])
        else if (_currentUserId == null)
          GestureDetector(
            onTap: () => Navigator.of(context).pushAndRemoveUntil(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const AuthGateScreen(),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 350),
              ),
              (_) => false,
            ),
            child: const Row(children: [
              Icon(Icons.login, size: 16, color: AppTheme.primary),
              SizedBox(width: 6),
              Text('Login untuk memberi rating',
                  style: TextStyle(color: AppTheme.primary, fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          )
        else
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _userRating > 0 ? 'Rating kamu:' : 'Beri rating resep ini:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _ratingLoading
                ? SizedBox(
                    height: 36,
                    child: Row(children: [
                      const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                      const SizedBox(width: 12),
                      Text('Menyimpan...', style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13)),
                    ]),
                  )
                : RatingBar.builder(
                    initialRating: _userRating,
                    minRating: 1,
                    itemSize: 36,
                    glowColor: Colors.amber.withValues(alpha: 0.3),
                    itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
                    onRatingUpdate: _submitRating,
                  ),
            if (_userRating > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Kamu memberi ${_userRating.toStringAsFixed(0)} bintang',
                  style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 12),
                ),
              ),
          ]),
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
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.recipe.ingredients[i],
              style: const TextStyle(fontSize: 15))),
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
            child: Text('${i + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(widget.recipe.steps[i],
                style: const TextStyle(fontSize: 15, height: 1.5)),
          )),
        ]),
      ),
    );
  }

  Widget _buildNutrition() {
    final noData = widget.recipe.calories == 0 && widget.recipe.protein == 0
        && widget.recipe.carbs == 0 && widget.recipe.fat == 0;
    if (noData) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.no_food, size: 60, color: AppTheme.textSubOn(context)),
        const SizedBox(height: 12),
        Text('Informasi nutrisi tidak tersedia',
            style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 15)),
        const SizedBox(height: 4),
        Text('Pemilik resep belum menambahkan data nutrisi',
            style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 12)),
      ]));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Per porsi',
              style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13)),
          const SizedBox(height: 16),
          _NutritionRow(
              label: 'Kalori',
              value: '${widget.recipe.calories} kkal',
              icon: Icons.local_fire_department,
              color: Colors.orange),
          _NutritionRow(
              label: 'Protein',
              value: '${widget.recipe.protein.toStringAsFixed(1)} g',
              icon: Icons.egg,
              color: Colors.blue),
          _NutritionRow(
              label: 'Karbohidrat',
              value: '${widget.recipe.carbs.toStringAsFixed(1)} g',
              icon: Icons.grain,
              color: Colors.green),
          _NutritionRow(
              label: 'Lemak',
              value: '${widget.recipe.fat.toStringAsFixed(1)} g',
              icon: Icons.opacity,
              color: Colors.red),
          const SizedBox(height: 20),
          if (widget.recipe.calories > 0) _buildMacroBar(),
        ],
      ),
    );
  }

  Widget _buildMacroBar() {
    final total = (widget.recipe.protein * 4) + (widget.recipe.carbs * 4) + (widget.recipe.fat * 9);
    if (total == 0) return const SizedBox();
    final pProt = (widget.recipe.protein * 4) / total;
    final pCarb = (widget.recipe.carbs * 4) / total;
    final pFat  = (widget.recipe.fat * 9) / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Distribusi Makronutrisi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(children: [
            Flexible(flex: (pProt * 100).round(), child: Container(height: 20, color: Colors.blue)),
            Flexible(flex: (pCarb * 100).round(), child: Container(height: 20, color: Colors.green)),
            Flexible(flex: (pFat  * 100).round(), child: Container(height: 20, color: Colors.red)),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _MacroLegend(color: Colors.blue,  label: 'Protein ${(pProt * 100).round()}%'),
          const SizedBox(width: 16),
          _MacroLegend(color: Colors.green, label: 'Karbo ${(pCarb * 100).round()}%'),
          const SizedBox(width: 16),
          _MacroLegend(color: Colors.red,   label: 'Lemak ${(pFat * 100).round()}%'),
        ]),
      ],
    );
  }

  Widget _buildComments() {
    return _CommentsTab(
      recipeId: widget.recipe.id,
      fs: _fs,
      onCommentAdded: () {
        if (mounted) setState(() => _commentCount++);
      },
    );
  }

  Widget _buildBottomBar() {
    if (_isOwner) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            OutlinedButton.icon(
              onPressed: _deleteFromCommunity,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Hapus', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _editRecipe,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Resep'),
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: _isLiked ? Colors.red : AppTheme.primary.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : AppTheme.primary),
              onPressed: _likeLoading ? null : _toggleLike,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (_isSaving || _isSaved) ? null : _saveToLocal,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_isSaved ? Icons.bookmark : Icons.bookmark_add_outlined),
              label: Text(_isSaving
                  ? 'Menyimpan...'
                  : _isSaved
                      ? 'Tersimpan di Koleksi'
                      : 'Simpan ke Koleksi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved ? Colors.grey[400] : AppTheme.primary,
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

class _CommentsTab extends StatefulWidget {
  final String recipeId;
  final FirestoreService fs;
  final VoidCallback? onCommentAdded;
  const _CommentsTab({required this.recipeId, required this.fs, this.onCommentAdded});

  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab> {
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool  _sending    = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    if (_uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login dulu untuk berkomentar')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.fs.addComment(widget.recipeId, text);
      _textCtrl.clear();
      widget.onCommentAdded?.call();
      if (mounted) {
        // Scroll ke bawah setelah komentar dikirim
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('permission-denied')
            ? 'Akses ditolak — cek Firestore Rules di Firebase Console'
            : 'Gagal mengirim komentar. Coba lagi.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String commentId) async {
    try {
      await widget.fs.deleteComment(widget.recipeId, commentId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus komentar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: StreamBuilder<List<RecipeComment>>(
          stream: widget.fs.getComments(widget.recipeId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
            }
            final comments = snap.data ?? [];
            if (comments.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.textSubOn(context)),
                  const SizedBox(height: 12),
                  Text('Belum ada komentar. Jadilah yang pertama!',
                      style: TextStyle(color: AppTheme.textSubOn(context)),
                      textAlign: TextAlign.center),
                ]),
              );
            }
            return ListView.separated(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _CommentBubble(
                comment: comments[i],
                isOwn: comments[i].userId == _uid,
                onDelete: () => _delete(comments[i].id),
              ),
            );
          },
        ),
      ),
      const Divider(height: 1),
      _buildInputBar(),
    ]);
  }

  Widget _buildInputBar() {
    if (_uid == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Login untuk berkomentar',
          style: TextStyle(color: AppTheme.textSubOn(context)),
          textAlign: TextAlign.center,
        ),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: null,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Tulis komentar...',
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.borderOn(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.borderOn(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          _sending
              ? const SizedBox(
                  width: 40, height: 40,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                  onPressed: _send,
                  tooltip: 'Kirim komentar',
                ),
        ]),
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final RecipeComment comment;
  final bool isOwn;
  final VoidCallback onDelete;
  const _CommentBubble({required this.comment, required this.isOwn, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(
        radius: 18,
        backgroundImage: comment.userPhoto.isNotEmpty ? NetworkImage(comment.userPhoto) : null,
        backgroundColor: AppTheme.primary,
        child: comment.userPhoto.isEmpty
            ? const Icon(Icons.person, size: 18, color: Colors.white)
            : null,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(
              comment.userName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (isOwn) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Kamu',
                    style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ),
            ],
            const Spacer(),
            if (comment.createdAt != null)
              Text(
                DateFormat('d MMM, HH:mm', 'id_ID').format(comment.createdAt!),
                style: TextStyle(fontSize: 11, color: AppTheme.textSubOn(context)),
              ),
            if (isOwn)
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isOwn
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : AppTheme.surfaceOn(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(comment.text, style: const TextStyle(fontSize: 14, height: 1.4)),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Komentar'),
        content: const Text('Yakin ingin menghapus komentar ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) onDelete();
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
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(fontSize: 15)),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
      Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
    ]);
  }
}
