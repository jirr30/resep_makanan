import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/error_view.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _db.getShoppingList();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Future<void> _addItem() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl  = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Item'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama bahan *', hintText: 'misal: Garam')),
          const SizedBox(height: 12),
          TextField(controller: qtyCtrl,
            decoration: const InputDecoration(labelText: 'Jumlah (opsional)', hintText: 'misal: 2 sdm')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final nav = Navigator.of(context);
              await _db.addShoppingItem(nameCtrl.text.trim(),
                quantity: qtyCtrl.text.trim().isEmpty ? null : qtyCtrl.text.trim(),
              );
              nav.pop();
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    qtyCtrl.dispose();
    _load();
  }

  Future<void> _clearChecked() async {
    final checked = _items.where((i) => i['isChecked'] == 1).length;
    if (checked == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada item yang sudah dicentang')));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus yang Sudah Dibeli?'),
        content: Text('$checked item yang sudah dicentang akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm == true) {
      await _db.clearCheckedShoppingItems();
      _load();
    }
  }

  Future<void> _clearAll() async {
    if (_items.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Semua Item?'),
        content: const Text('Seluruh daftar belanja akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.clearAllShoppingItems();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unchecked = _items.where((i) => i['isChecked'] == 0).toList();
    final checked   = _items.where((i) => i['isChecked'] == 1).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Belanja'),
        actions: [
          IconButton(icon: const Icon(Icons.remove_done), onPressed: _clearChecked, tooltip: 'Hapus yang sudah dibeli'),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'clear') _clearAll(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'clear', child: Row(children: [
                Icon(Icons.delete_sweep, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Hapus Semua', style: TextStyle(color: Colors.red)),
              ])),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _items.isEmpty
              ? EmptyView(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Daftar Belanja Kosong',
                  subtitle: 'Tambahkan bahan belanja atau generate dari resep',
                  actionLabel: 'Tambah Item',
                  onAction: _addItem,
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    if (unchecked.isNotEmpty) ...[
                      _sectionHeader('Belum Dibeli (${unchecked.length})'),
                      ...unchecked.map((item) => _buildItem(item)),
                    ],
                    if (checked.isNotEmpty) ...[
                      _sectionHeader('Sudah Dibeli (${checked.length})'),
                      ...checked.map((item) => _buildItem(item)),
                    ],
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSubOn(context), fontSize: 13)),
  );

  Widget _buildItem(Map<String, dynamic> item) {
    final checked = item['isChecked'] == 1;
    return Dismissible(
      key: Key('shop_${item['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _db.deleteShoppingItem(item['id'] as int);
        _load();
      },
      child: ListTile(
        leading: Checkbox(
          value: checked,
          activeColor: AppTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: (v) async {
            await _db.toggleShoppingItem(item['id'] as int, v ?? false);
            _load();
          },
        ),
        title: Text(
          item['name'] as String,
          style: TextStyle(decoration: checked ? TextDecoration.lineThrough : null, color: checked ? AppTheme.textSubOn(context) : null),
        ),
        subtitle: item['quantity'] != null ? Text(item['quantity'] as String, style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 13)) : null,
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.textSubOn(context)),
          onPressed: () async { await _db.deleteShoppingItem(item['id'] as int); _load(); },
        ),
      ),
    );
  }
}
