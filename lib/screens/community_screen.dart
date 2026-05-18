import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import 'community_detail_screen.dart';
import 'login_screen.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
                onTap: () => _showProfileMenu(context, auth),
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
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Login'),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Semua Resep'),
            Tab(text: 'Resep Saya'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AllRecipesTab(fs: _fs),
          auth.isLoggedIn
              ? _MyRecipesTab(fs: _fs)
              : _LoginPrompt(onLogin: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()))),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 36,
            backgroundImage: auth.user?.photoURL != null ? NetworkImage(auth.user!.photoURL!) : null,
            backgroundColor: AppTheme.primary,
            child: auth.user?.photoURL == null ? const Icon(Icons.person, size: 32, color: Colors.white) : null,
          ),
          const SizedBox(height: 12),
          Text(auth.user?.displayName ?? 'Pengguna', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(auth.user?.email ?? '', style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await auth.signOut();
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Keluar', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AllRecipesTab extends StatelessWidget {
  final FirestoreService fs;
  const _AllRecipesTab({required this.fs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommunityRecipe>>(
      stream: fs.getCommunityRecipes(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        if (snap.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text('Gagal memuat: ${snap.error}', style: const TextStyle(color: AppTheme.textSecondary)),
          ]));
        }
        final recipes = snap.data ?? [];
        if (recipes.isEmpty) {
          return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('Belum ada resep dari komunitas', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            SizedBox(height: 8),
            Text('Jadilah yang pertama berbagi!', style: TextStyle(color: AppTheme.textSecondary)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: recipes.length,
          itemBuilder: (_, i) => _CommunityCard(recipe: recipes[i], fs: fs),
        );
      },
    );
  }
}

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
    final r = await widget.fs.getMyRecipes();
    if (mounted) setState(() { _recipes = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_recipes.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.restaurant_menu, size: 64, color: AppTheme.textSecondary),
        SizedBox(height: 16),
        Text('Belum ada resep yang kamu bagikan', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
      ]));
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
            await widget.fs.deleteRecipe(_recipes[i].id);
            _load();
          },
        ),
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final CommunityRecipe recipe;
  final FirestoreService fs;
  final bool showDelete;
  final VoidCallback? onDelete;

  const _CommunityCard({required this.recipe, required this.fs, this.showDelete = false, this.onDelete});

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
            child: Image.network(
              recipe.imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: AppTheme.primary.withValues(alpha: 0.15),
                child: const Icon(Icons.restaurant, size: 48, color: AppTheme.primary),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundImage: recipe.authorPhoto.isNotEmpty ? NetworkImage(recipe.authorPhoto) : null,
                  backgroundColor: AppTheme.primary,
                  child: recipe.authorPhoto.isEmpty ? const Icon(Icons.person, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(recipe.authorName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  if (recipe.publishedAt != null)
                    Text(DateFormat('d MMM yyyy', 'id_ID').format(recipe.publishedAt!),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ])),
                if (showDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Hapus resep',
                  ),
              ]),
              const SizedBox(height: 8),
              Text(recipe.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(recipe.description,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
                Text('${recipe.likes}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
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
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDFE6E9)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
        const Icon(Icons.lock_outline, size: 64, color: AppTheme.textSecondary),
        const SizedBox(height: 16),
        const Text('Login untuk melihat resep kamu', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onLogin,
          icon: const Icon(Icons.login),
          label: const Text('Login Sekarang'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
        ),
      ]),
    ));
  }
}
