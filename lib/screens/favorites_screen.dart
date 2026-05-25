import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../widgets/shimmer_card.dart';
import '../widgets/error_view.dart';
import 'community_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _fs = FirestoreService();
  List<CommunityRecipe> _liked = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _hasError = false; });
    try {
      final liked = await _fs.getUserLikedRecipes();
      if (mounted) setState(() { _liked = liked; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  Future<void> _unlike(CommunityRecipe recipe) async {
    await _fs.toggleLike(recipe.id, false);
    setState(() => _liked.removeWhere((r) => r.id == recipe.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${recipe.title}" dibatalkan liknya'),
      action: SnackBarAction(
        label: 'Batalkan',
        textColor: Colors.amber,
        onPressed: () async {
          await _fs.toggleLike(recipe.id, true);
          _load();
        },
      ),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resep Disukai')),
      body: _hasError
          ? ErrorView(message: 'Gagal memuat resep', onRetry: _load)
          : _loading
              ? const ShimmerList(count: 4)
              : _liked.isEmpty
                  ? const EmptyView(
                      icon: Icons.favorite_border,
                      title: 'Belum Ada Resep Disukai',
                      subtitle: 'Like resep komunitas yang kamu sukai\ndan akan muncul di sini',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _liked.length,
                        itemBuilder: (_, i) => Dismissible(
                          key: Key('liked_${_liked[i].id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.heart_broken_outlined, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            await _unlike(_liked[i]);
                            return false; // state sudah diupdate manual via removeWhere
                          },
                          child: _LikedCard(
                            recipe: _liked[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CommunityDetailScreen(recipe: _liked[i])),
                            ).then((_) => _load()),
                            onUnlike: () => _unlike(_liked[i]),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

// ── Liked recipe card ─────────────────────────────────────────────────────────

class _LikedCard extends StatelessWidget {
  final CommunityRecipe recipe;
  final VoidCallback onTap;
  final VoidCallback onUnlike;

  const _LikedCard({
    required this.recipe,
    required this.onTap,
    required this.onUnlike,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Thumbnail
            SizedBox(
              width: 100,
              height: 100,
              child: recipe.imageUrl.isNotEmpty
                  ? Image.network(
                      recipe.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.authorName,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.favorite, size: 13, color: Colors.red),
                        const SizedBox(width: 4),
                        Text('${recipe.likes}',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(width: 12),
                        const Icon(Icons.timer_outlined, size: 13),
                        const SizedBox(width: 4),
                        Text('${recipe.cookingTime} mnt',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Unlike button
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              tooltip: 'Batalkan like',
              onPressed: onUnlike,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: Colors.grey.shade200,
    child: const Icon(Icons.restaurant, color: Colors.grey, size: 36),
  );
}
