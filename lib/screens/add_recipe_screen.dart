import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController();

  String _category = AppConstants.categories[1];
  String _difficulty = AppConstants.difficulties[0];
  final List<TextEditingController> _ingredientCtrls = [TextEditingController()];
  final List<TextEditingController> _stepCtrls = [TextEditingController()];
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _imageCtrl.dispose();
    _timeCtrl.dispose();
    _servingsCtrl.dispose();
    for (final c in _ingredientCtrls) { c.dispose(); }
    for (final c in _stepCtrls) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final recipe = Recipe(
      title: _titleCtrl.text.trim(),
      category: _category,
      description: _descCtrl.text.trim(),
      imageUrl: _imageCtrl.text.trim().isEmpty
          ? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400'
          : _imageCtrl.text.trim(),
      ingredients: _ingredientCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
      steps: _stepCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
      cookingTime: int.tryParse(_timeCtrl.text) ?? 30,
      servings: int.tryParse(_servingsCtrl.text) ?? 2,
      difficulty: _difficulty,
    );

    await _db.insertRecipe(recipe);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resep berhasil disimpan!'), backgroundColor: AppTheme.primary),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Resep Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Informasi Dasar'),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Nama Resep *', prefixIcon: Icon(Icons.restaurant_menu)),
              validator: (v) => v?.trim().isEmpty == true ? 'Nama resep wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Deskripsi *', prefixIcon: Icon(Icons.description)),
              validator: (v) => v?.trim().isEmpty == true ? 'Deskripsi wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageCtrl,
              decoration: const InputDecoration(labelText: 'URL Gambar (opsional)', prefixIcon: Icon(Icons.image)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Kategori', prefixIcon: Icon(Icons.category)),
              items: AppConstants.categories.skip(1).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _timeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Waktu (menit) *', prefixIcon: Icon(Icons.timer)),
                    validator: (v) => v?.trim().isEmpty == true ? 'Wajib diisi' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _servingsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Porsi *', prefixIcon: Icon(Icons.people)),
                    validator: (v) => v?.trim().isEmpty == true ? 'Wajib diisi' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _difficulty,
              decoration: const InputDecoration(labelText: 'Tingkat Kesulitan', prefixIcon: Icon(Icons.bar_chart)),
              items: AppConstants.difficulties.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _difficulty = v!),
            ),
            const SizedBox(height: 20),
            _section('Bahan-bahan'),
            ..._ingredientCtrls.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: e.value,
                      decoration: InputDecoration(
                        labelText: 'Bahan ${e.key + 1}',
                        prefixIcon: const Icon(Icons.fiber_manual_record, size: 12, color: AppTheme.primary),
                      ),
                    ),
                  ),
                  if (_ingredientCtrls.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => setState(() {
                        _ingredientCtrls[e.key].dispose();
                        _ingredientCtrls.removeAt(e.key);
                      }),
                    ),
                ],
              ),
            )),
            TextButton.icon(
              onPressed: () => setState(() => _ingredientCtrls.add(TextEditingController())),
              icon: const Icon(Icons.add, color: AppTheme.primary),
              label: const Text('Tambah Bahan', style: TextStyle(color: AppTheme.primary)),
            ),
            const SizedBox(height: 20),
            _section('Langkah-langkah'),
            ..._stepCtrls.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, right: 8),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primary,
                      child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: e.value,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: 'Langkah ${e.key + 1}'),
                    ),
                  ),
                  if (_stepCtrls.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => setState(() {
                        _stepCtrls[e.key].dispose();
                        _stepCtrls.removeAt(e.key);
                      }),
                    ),
                ],
              ),
            )),
            TextButton.icon(
              onPressed: () => setState(() => _stepCtrls.add(TextEditingController())),
              icon: const Icon(Icons.add, color: AppTheme.primary),
              label: const Text('Tambah Langkah', style: TextStyle(color: AppTheme.primary)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Simpan Resep', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
    );
  }
}
