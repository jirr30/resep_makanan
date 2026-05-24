import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import 'detail_screen.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _collections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cols = await _db.getCollections();
    if (mounted) setState(() { _collections = cols; _loading = false; });
  }

  Future<void> _createCollection() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Koleksi Baru'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama koleksi',
            hintText: 'misal: Resep Diet',
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Buat'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await _db.createCollection(ctrl.text.trim());
      _load();
    }
  }

  Future<void> _renameCollection(Map<String, dynamic> col) async {
    final ctrl = TextEditingController(text: col['name'] as String);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ubah Nama'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama koleksi'),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await _db.renameCollection(col['id'] as int, ctrl.text.trim());
      _load();
    }
  }

  Future<void> _deleteCollection(Map<String, dynamic> col) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Koleksi'),
        content: Text('Hapus koleksi "${col['name']}"? Resep di dalamnya tidak akan ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.deleteCollection(col['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Koleksi Resep')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _collections.isEmpty
              ? _buildEmpty()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _collections.length,
                  itemBuilder: (_, i) => _CollectionCard(
                    collection: _collections[i],
                    onTap: () => _openCollection(_collections[i]),
                    onRename: () => _renameCollection(_collections[i]),
                    onDelete: () => _deleteCollection(_collections[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createCollection,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, Color(0xFFFF8C55)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.collections_bookmark, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text('Belum ada koleksi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textOn(context))),
          const SizedBox(height: 8),
          Text('Buat koleksi untuk mengelompokkan resep favoritmu',
              style: TextStyle(color: AppTheme.textSubOn(context), height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createCollection,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Buat Koleksi Pertama', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }

  void _openCollection(Map<String, dynamic> col) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CollectionDetailScreen(collection: col),
    )).then((_) => _load());
  }
}

// ─── Collection Card ──────────────────────────────────────────────────────────

class _CollectionCard extends StatelessWidget {
  final Map<String, dynamic> collection;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CollectionCard({
    required this.collection,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final count = collection['recipeCount'] as int? ?? 0;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFFFF8C55)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.collections_bookmark, color: Colors.white, size: 22),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    onSelected: (v) {
                      if (v == 'rename') onRename();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Ubah Nama'),
                      ])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8),
                        Text('Hapus', style: TextStyle(color: Colors.red)),
                      ])),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(collection['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('$count resep',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Collection Detail Screen ─────────────────────────────────────────────────

class CollectionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> collection;
  const CollectionDetailScreen({super.key, required this.collection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final _db = DatabaseService();
  List<Recipe> _recipes = [];
  bool _loading = true;

  int get _collectionId => widget.collection['id'] as int;
  String get _name => widget.collection['name'] as String;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final recipes = await _db.getCollectionRecipes(_collectionId);
    if (mounted) setState(() { _recipes = recipes; _loading = false; });
  }

  Future<void> _removeRecipe(Recipe recipe) async {
    await _db.removeRecipeFromCollection(_collectionId, recipe.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_name, overflow: TextOverflow.ellipsis)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _recipes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.restaurant_menu, size: 64, color: AppTheme.textSubOn(context)),
                      const SizedBox(height: 12),
                      Text('Koleksi kosong',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textOn(context))),
                      const SizedBox(height: 8),
                      Text('Tambahkan resep dari halaman detail resep',
                          style: TextStyle(color: AppTheme.textSubOn(context)),
                          textAlign: TextAlign.center),
                    ]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _recipes.length,
                  itemBuilder: (_, i) => _CollectionRecipeItem(
                    recipe: _recipes[i],
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => DetailScreen(recipe: _recipes[i]))),
                    onRemove: () => _removeRecipe(_recipes[i]),
                  ),
                ),
    );
  }
}

class _CollectionRecipeItem extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _CollectionRecipeItem({required this.recipe, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: recipe.imageUrl.isNotEmpty
            ? Image.network(recipe.imageUrl, width: 48, height: 48, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder())
            : _placeholder(),
      ),
      title: Text(recipe.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(recipe.category,
          style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
      trailing: IconButton(
        icon: Icon(Icons.remove_circle_outline, color: AppTheme.textSubOn(context)),
        tooltip: 'Hapus dari koleksi',
        onPressed: onRemove,
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 48, height: 48,
    color: AppTheme.primary.withValues(alpha: 0.1),
    child: const Icon(Icons.restaurant, color: AppTheme.primary, size: 20),
  );
}

// ─── Save to Collection Bottom Sheet ─────────────────────────────────────────

/// Shows a bottom sheet to save/remove a recipe from user's collections.
Future<void> showSaveToCollectionSheet(BuildContext context, Recipe recipe) async {
  final db = DatabaseService();
  final recipeId = recipe.id;
  if (recipeId == null) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SaveToCollectionSheet(db: db, recipeId: recipeId),
  );
}

class _SaveToCollectionSheet extends StatefulWidget {
  final DatabaseService db;
  final int recipeId;
  const _SaveToCollectionSheet({required this.db, required this.recipeId});

  @override
  State<_SaveToCollectionSheet> createState() => _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState extends State<_SaveToCollectionSheet> {
  List<Map<String, dynamic>> _collections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cols = await widget.db.getCollectionsForRecipe(widget.recipeId);
    if (mounted) setState(() { _collections = cols; _loading = false; });
  }

  Future<void> _toggle(Map<String, dynamic> col) async {
    final isAdded = (col['isAdded'] as int? ?? 0) > 0;
    if (isAdded) {
      await widget.db.removeRecipeFromCollection(col['id'] as int, widget.recipeId);
    } else {
      await widget.db.addRecipeToCollection(col['id'] as int, widget.recipeId);
    }
    _load();
  }

  Future<void> _createAndAdd() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Koleksi Baru'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama koleksi'),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Buat'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      final newId = await widget.db.createCollection(ctrl.text.trim());
      await widget.db.addRecipeToCollection(newId, widget.recipeId);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.collections_bookmark, color: AppTheme.primary),
            const SizedBox(width: 10),
            const Text('Simpan ke Koleksi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: _createAndAdd,
              icon: const Icon(Icons.add, size: 16, color: AppTheme.primary),
              label: const Text('Baru', style: TextStyle(color: AppTheme.primary)),
            ),
          ]),
          const Divider(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          else if (_collections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Belum ada koleksi. Buat koleksi baru.',
                  style: TextStyle(color: AppTheme.textSubOn(context))),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _collections.length,
                itemBuilder: (_, i) {
                  final col     = _collections[i];
                  final isAdded = (col['isAdded'] as int? ?? 0) > 0;
                  final count   = col['recipeCount'] as int? ?? 0;
                  return ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.collections_bookmark, color: AppTheme.primary, size: 20),
                    ),
                    title: Text(col['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('$count resep',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context))),
                    trailing: isAdded
                        ? const Icon(Icons.check_circle, color: AppTheme.primary)
                        : Icon(Icons.add_circle_outline, color: AppTheme.textSubOn(context)),
                    onTap: () => _toggle(col),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
