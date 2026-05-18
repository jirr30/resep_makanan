import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';

class DetailScreen extends StatefulWidget {
  final Recipe recipe;

  const DetailScreen({super.key, required this.recipe});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Recipe _recipe;
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    await _db.toggleFavorite(_recipe.id!, !_recipe.isFavorite);
    setState(() => _recipe = _recipe.copyWith(isFavorite: !_recipe.isFavorite));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.primary,
            actions: [
              IconButton(
                icon: Icon(_recipe.isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: _toggleFavorite,
              ),
              IconButton(icon: const Icon(Icons.share), onPressed: _shareRecipe),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                _recipe.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  child: const Icon(Icons.restaurant, size: 80, color: Colors.white),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
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
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(_recipe.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Text(_recipe.description, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.5)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StatCard(icon: Icons.timer, value: '${_recipe.cookingTime}', unit: 'menit'),
                          const SizedBox(width: 12),
                          _StatCard(icon: Icons.people, value: '${_recipe.servings}', unit: 'porsi'),
                          const SizedBox(width: 12),
                          _StatCard(icon: Icons.bar_chart, value: _recipe.difficulty, unit: 'tingkat'),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primary,
                  tabs: const [
                    Tab(text: 'Bahan-bahan'),
                    Tab(text: 'Cara Memasak'),
                  ],
                ),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIngredients(),
                      _buildSteps(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredients() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recipe.ingredients.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_recipe.ingredients[i], style: const TextStyle(fontSize: 15))),
          ],
        ),
      ),
    );
  }

  Widget _buildSteps() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recipe.steps.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_recipe.steps[i], style: const TextStyle(fontSize: 15, height: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
            Text(unit, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
