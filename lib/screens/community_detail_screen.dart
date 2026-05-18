import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';

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

  double _userRating    = 0.0;
  bool   _ratingLoading = false;
  double _averageRating = 0.0;
  int    _ratingCount   = 0;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  bool get _isOwner => _currentUserId != null && _currentUserId == widget.recipe.authorId;

  @override
  void initState() {
    super.initState();
    _tabController  = TabController(length: 4, vsync: this);
    _likes          = widget.recipe.likes;
    _averageRating  = widget.recipe.averageRating;
    _ratingCount    = widget.recipe.ratingCount;
    _loadLikeStatus();
    _loadUserRating();
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
          SliverToBoxAdapter(child: _buildRatingSection()),
          SliverToBoxAdapter(
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              indicatorColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: [
                const Tab(text: 'Bahan'),
                const Tab(text: 'Cara Masak'),
                const Tab(text: 'Nutrisi'),
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Komentar'),
                    if (widget.recipe.commentCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.recipe.commentCount}',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ]),
                ),
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
                _buildComments(),
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
        if (_isOwner)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _deleteFromCommunity,
            tooltip: 'Hapus dari komunitas',
          ),
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
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildAuthorInfo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
            Text(widget.recipe.authorName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (_isOwner) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                child: const Text('Kamu',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),

        // Aksi rating user
        if (_isOwner)
          Row(children: const [
            Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
            SizedBox(width: 6),
            Text('Kamu tidak bisa menilai resep sendiri',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ])
        else if (_currentUserId == null)
          GestureDetector(
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
              if (mounted) _loadUserRating();
            },
            child: Row(children: [
              const Icon(Icons.login, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text('Login untuk memberi rating',
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
                ? const SizedBox(
                    height: 36,
                    child: Row(children: [
                      SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                      SizedBox(width: 12),
                      Text('Menyimpan...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.info_outline, size: 48, color: AppTheme.textSecondary),
        SizedBox(height: 12),
        Text('Informasi nutrisi tidak tersedia',
            style: TextStyle(color: AppTheme.textSecondary)),
      ]));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _NutritionCard('Kalori', '${widget.recipe.calories}', 'kkal',
            Icons.local_fire_department, Colors.orange),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _NutritionCard('Protein',
              widget.recipe.protein.toStringAsFixed(1), 'g', Icons.egg, Colors.blue)),
          const SizedBox(width: 12),
          Expanded(child: _NutritionCard('Karbo',
              widget.recipe.carbs.toStringAsFixed(1), 'g', Icons.grain, Colors.amber)),
          const SizedBox(width: 12),
          Expanded(child: _NutritionCard('Lemak',
              widget.recipe.fat.toStringAsFixed(1), 'g', Icons.opacity, Colors.red)),
        ]),
      ]),
    );
  }

  Widget _buildComments() {
    return _CommentsTab(recipeId: widget.recipe.id, fs: _fs);
  }

  Widget _buildBottomBar() {
    if (_isOwner) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _deleteFromCommunity,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Hapus dari Komunitas',
                style: TextStyle(color: Colors.red)),
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
              onPressed: _isSaving ? null : _saveToLocal,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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

class _CommentsTab extends StatefulWidget {
  final String recipeId;
  final FirestoreService fs;
  const _CommentsTab({required this.recipeId, required this.fs});

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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim komentar. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String commentId) async {
    await widget.fs.deleteComment(widget.recipeId, commentId);
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
              return const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.textSecondary),
                  SizedBox(height: 12),
                  Text('Belum ada komentar. Jadilah yang pertama!',
                      style: TextStyle(color: AppTheme.textSecondary),
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
        child: const Text(
          'Login untuk berkomentar',
          style: TextStyle(color: AppTheme.textSecondary),
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
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
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
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
                  : Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.surfaceDark
                      : AppTheme.bgLight,
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
