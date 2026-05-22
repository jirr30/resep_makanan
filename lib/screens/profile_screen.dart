import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import 'add_recipe_screen.dart';
import 'community_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fs = FirestoreService();
  UserProfileStats? _stats;
  bool    _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      _fs.syncCurrentUserProfile();
      final stats = await _fs.getUserStats(uid);
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e; _loading = false; });
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari akun?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().signOut();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Keluar',
            onPressed: _signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(user)),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.cloud_off_outlined, size: 64, color: AppTheme.textSubOn(context)),
                      const SizedBox(height: 16),
                      Text(
                        'Gagal memuat profil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textOn(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Periksa koneksi internet kamu dan coba lagi',
                        style: TextStyle(color: AppTheme.textSubOn(context)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ]),
                  ),
                ),
              )
            else if (_stats != null) ...[
              SliverToBoxAdapter(child: _buildStats()),
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
              if (_stats!.recipes.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, Color(0xFFFF8C55)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.restaurant_menu, size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Belum ada resep yang dibagikan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textOn(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bagikan resepmu ke komunitas agar\nchef lain bisa melihat kreasimu!',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSubOn(context),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
                          ).then((_) => _load()),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Bagikan Resep Sekarang',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _ProfileRecipeCard(
                      recipe: _stats!.recipes[i],
                      fs: _fs,
                      onDeleted: _load,
                    ),
                    childCount: _stats!.recipes.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(User user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
          backgroundColor: AppTheme.primary,
          child: user.photoURL == null
              ? const Icon(Icons.person, size: 48, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          user.displayName ?? 'Pengguna',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          user.email ?? '',
          style: TextStyle(fontSize: 14, color: AppTheme.textSubOn(context)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFF4285F4), width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Text(
                'G',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4285F4),
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text('Google Account',
                style: TextStyle(fontSize: 12, color: AppTheme.primary)),
          ]),
        ),
        if (_stats != null) ...[
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _FollowStat(label: 'Followers', value: _stats!.followerCount),
            Container(width: 1, height: 32, color: AppTheme.borderOn(context)),
            _FollowStat(label: 'Mengikuti', value: _stats!.followingCount),
          ]),
        ],
        if (user.metadata.creationTime != null) ...[
          const SizedBox(height: 8),
          Text(
            'Bergabung ${DateFormat('MMMM yyyy', 'id_ID').format(user.metadata.creationTime!)}',
            style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context)),
          ),
        ],
      ]),
    );
  }

  Widget _buildStats() {
    final s = _stats!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Row(children: [
          _StatCard(
            label: 'Resep',
            value: '${s.recipeCount}',
            icon: Icons.restaurant_menu,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Total Likes',
            value: '${s.totalLikes}',
            icon: Icons.favorite,
            color: Colors.red,
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _StatCard(
            label: 'Total Dilihat',
            value: _fmtView(s.totalViews),
            icon: Icons.remove_red_eye_outlined,
            color: Colors.blueGrey,
          ),
          const SizedBox(width: 12),
          _StatCard(
            label: 'Avg Rating',
            value: s.averageRating > 0 ? s.averageRating.toStringAsFixed(1) : '-',
            icon: Icons.star,
            color: Colors.amber,
          ),
        ]),
      ]),
    );
  }
}

class _FollowStat extends StatelessWidget {
  final String label;
  final int    value;
  const _FollowStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        Text(_fmt(value),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
      ]),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}jt';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}rb';
    return '$n';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSubOn(context))),
        ]),
      ),
    );
  }
}

String _fmtView(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}jt';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}rb';
  return '$count';
}

class _ProfileRecipeCard extends StatelessWidget {
  final CommunityRecipe recipe;
  final FirestoreService fs;
  final VoidCallback onDeleted;
  const _ProfileRecipeCard({required this.recipe, required this.fs, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(recipe: recipe),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: recipe.imageUrl.isNotEmpty
                  ? Image.network(recipe.imageUrl, width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(recipe.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.favorite, size: 13, color: Colors.red),
                const SizedBox(width: 4),
                Text('${recipe.likes}', style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
                const SizedBox(width: 12),
                const Icon(Icons.star, size: 13, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  recipe.averageRating > 0
                      ? recipe.averageRating.toStringAsFixed(1)
                      : '-',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context)),
                ),
                const SizedBox(width: 12),
                Icon(Icons.comment_outlined, size: 13, color: AppTheme.textSubOn(context)),
                const SizedBox(width: 4),
                Text('${recipe.commentCount}', style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
                const SizedBox(width: 12),
                Icon(Icons.remove_red_eye_outlined, size: 13, color: AppTheme.textSubOn(context)),
                const SizedBox(width: 4),
                Text(_fmtView(recipe.viewCount), style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
              ]),
              if (recipe.publishedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM yyyy', 'id_ID').format(recipe.publishedAt!),
                  style: TextStyle(fontSize: 11, color: AppTheme.textSubOn(context)),
                ),
              ],
            ])),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              tooltip: 'Hapus resep',
              onPressed: () => _confirmDelete(context),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 72, height: 72,
    color: AppTheme.primary.withValues(alpha: 0.1),
    child: const Icon(Icons.restaurant, color: AppTheme.primary),
  );

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Resep'),
        content: Text('Hapus "${recipe.title}" dari komunitas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await fs.deleteRecipe(recipe.id);
      onDeleted();
    }
  }
}
