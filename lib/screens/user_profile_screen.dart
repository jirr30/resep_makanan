import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'community_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String  userId;
  final String? initialName;
  final String? initialPhoto;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.initialPhoto,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _fs = FirestoreService();

  UserProfileStats? _stats;
  bool  _loading       = true;
  bool? _isFollowing;   // null = belum dimuat
  bool  _followLoading = false;

  String? get _currentUid  => FirebaseAuth.instance.currentUser?.uid;
  bool   get _isOwnProfile => _currentUid == widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final futures = <Future>[_fs.getUserStats(widget.userId)];
      if (!_isOwnProfile && _currentUid != null) {
        futures.add(_fs.isFollowing(widget.userId));
      }
      final results = await Future.wait(futures);
      if (mounted) {
        setState(() {
          _stats       = results[0] as UserProfileStats;
          _isFollowing = results.length > 1 ? results[1] as bool : null;
          _loading     = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildFollowSkeleton() {
    return Container(
      key: const ValueKey('skeleton'),
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (_currentUid == null || _isOwnProfile || _isFollowing == null) return;
    setState(() => _followLoading = true);
    final wasFollowing = _isFollowing!;
    try {
      if (wasFollowing) {
        await _fs.unfollowUser(widget.userId);
      } else {
        await _fs.followUser(widget.userId);
      }
      if (mounted) {
        setState(() {
          _isFollowing = !wasFollowing;
          if (_stats != null) {
            _stats = UserProfileStats(
              displayName:    _stats!.displayName,
              photoURL:       _stats!.photoURL,
              recipeCount:    _stats!.recipeCount,
              totalLikes:     _stats!.totalLikes,
              totalViews:     _stats!.totalViews,
              averageRating:  _stats!.averageRating,
              recipes:        _stats!.recipes,
              followerCount:  _stats!.followerCount + (wasFollowing ? -1 : 1),
              followingCount: _stats!.followingCount,
            );
          }
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _stats?.displayName ?? widget.initialName ?? 'Profil',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  if (_stats != null && _stats!.recipes.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'Resep yang Dipublikasikan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _PublicRecipeCard(recipe: _stats!.recipes[i]),
                        childCount: _stats!.recipes.length,
                      ),
                    ),
                  ] else if (_stats != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.restaurant_menu, size: 64,
                                color: AppTheme.textSubOn(context)),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada resep yang dipublikasikan',
                              style: TextStyle(color: AppTheme.textSubOn(context)),
                              textAlign: TextAlign.center,
                            ),
                          ]),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final stats    = _stats;
    final photoURL = stats?.photoURL ?? widget.initialPhoto ?? '';
    final name     = stats?.displayName ?? widget.initialName ?? 'Pengguna';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
          backgroundColor: AppTheme.primary,
          child: photoURL.isEmpty
              ? const Icon(Icons.person, size: 48, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 16),
        Text(name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Stats: Resep · Followers · Mengikuti
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _StatCol(label: 'Resep', value: stats?.recipeCount ?? 0),
          _VertDivider(),
          _StatCol(label: 'Followers', value: stats?.followerCount ?? 0),
          _VertDivider(),
          _StatCol(label: 'Mengikuti', value: stats?.followingCount ?? 0),
        ]),

        const SizedBox(height: 20),

        // Follow / Unfollow button
        if (!_isOwnProfile && _currentUid != null)
          SizedBox(
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _followLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                    )
                  : _isFollowing == null
                      ? _buildFollowSkeleton()
                      : _isFollowing!
                          ? OutlinedButton.icon(
                              key: const ValueKey('unfollow'),
                              onPressed: _toggleFollow,
                              icon: const Icon(Icons.person_remove_outlined, size: 18),
                              label: const Text('Mengikuti'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: AppTheme.primary),
                                foregroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            )
                          : ElevatedButton.icon(
                              key: const ValueKey('follow'),
                              onPressed: _toggleFollow,
                              icon: const Icon(Icons.person_add_outlined, size: 18),
                              label: const Text('Ikuti'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
            ),
          ),
      ]),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _StatCol extends StatelessWidget {
  final String label;
  final int    value;
  const _StatCol({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        Text(_fmt(value),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
      ]),
    );
  }

  String _fmt(int n) => AppConstants.formatCount(n);
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1, height: 36, color: AppTheme.borderOn(context));
}


// ─── Recipe Card ──────────────────────────────────────────────────────────────

class _PublicRecipeCard extends StatelessWidget {
  final CommunityRecipe recipe;
  const _PublicRecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => CommunityDetailScreen(recipe: recipe))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: recipe.imageUrl.isNotEmpty
                  ? Image.network(recipe.imageUrl,
                      width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(recipe.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.favorite, size: 13, color: Colors.red),
                  const SizedBox(width: 4),
                  Text('${recipe.likes}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
                  const SizedBox(width: 10),
                  const Icon(Icons.star, size: 13, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    recipe.averageRating > 0
                        ? recipe.averageRating.toStringAsFixed(1)
                        : '-',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context)),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.remove_red_eye_outlined, size: 13,
                      color: AppTheme.textSubOn(context)),
                  const SizedBox(width: 4),
                  Text(AppConstants.formatCount(recipe.viewCount),
                      style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
                ]),
                if (recipe.publishedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d MMM yyyy', 'id_ID').format(recipe.publishedAt!),
                    style: TextStyle(fontSize: 11, color: AppTheme.textSubOn(context)),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 72, height: 72,
        color: AppTheme.primary.withValues(alpha: 0.1),
        child: const Icon(Icons.restaurant, color: AppTheme.primary));
}
