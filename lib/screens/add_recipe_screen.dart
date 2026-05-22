import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/nutrition_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _db          = DatabaseService();
  final _titleCtrl   = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _timeCtrl    = TextEditingController();
  final _servingsCtrl = TextEditingController();

  String _category   = AppConstants.categories[1];
  String _difficulty = AppConstants.difficulties[0];
  final List<TextEditingController> _ingredientCtrls = [TextEditingController()];
  final List<TextEditingController> _stepCtrls       = [TextEditingController()];
  String? _localImagePath;
  bool _saving = false;
  String _savingMessage = '';
  bool _shareToCommunity = false;

  @override
  void dispose() {
    for (final c in [_titleCtrl, _descCtrl, _timeCtrl, _servingsCtrl]) {
      c.dispose();
    }
    for (final c in _ingredientCtrls) { c.dispose(); }
    for (final c in _stepCtrls) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final dir  = await getApplicationDocumentsDirectory();
    final name = 'recipe_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
    final saved = await File(picked.path).copy('${dir.path}/$name');
    setState(() => _localImagePath = saved.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _savingMessage = 'Menghitung nutrisi...'; });

    final ingredients = _ingredientCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    final servings    = int.tryParse(_servingsCtrl.text) ?? 2;

    // Hitung nutrisi otomatis — jika gagal, simpan dengan nilai 0 (tidak blokir user)
    NutritionResult? nutrition;
    try {
      nutrition = await NutritionService().estimateFromIngredients(
        ingredients: ingredients,
        servings: servings,
      );
    } catch (_) {
      nutrition = null;
    }

    if (!mounted) return;
    setState(() => _savingMessage = 'Menyimpan resep...');

    var recipe = Recipe(
      title:       _titleCtrl.text.trim(),
      category:    _category,
      description: _descCtrl.text.trim(),
      imageUrl:    '',
      imagePath:   _localImagePath,
      ingredients: ingredients,
      steps:       _stepCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
      cookingTime: int.tryParse(_timeCtrl.text) ?? 30,
      servings:    servings,
      difficulty:  _difficulty,
      calories:    nutrition?.calories ?? 0,
      protein:     nutrition?.protein  ?? 0,
      carbs:       nutrition?.carbs    ?? 0,
      fat:         nutrition?.fat      ?? 0,
    );

    try {
      final id = await _db.insertRecipe(recipe);

      bool sharedToCommunity = false;
      if (_shareToCommunity && FirebaseAuth.instance.currentUser != null) {
        setState(() => _savingMessage = 'Membagikan ke komunitas...');
        try {
          final firestoreId = await FirestoreService().publishRecipe(recipe);
          if (firestoreId != null) {
            recipe = recipe.copyWith(id: id, firestoreId: firestoreId);
            await _db.updateRecipe(recipe);
            sharedToCommunity = true;
          }
        } catch (e) {
          // Simpan berhasil, tapi share gagal — beri tahu user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Gagal dibagikan: $e'),
              duration: const Duration(seconds: 6),
            ));
          }
        }
      }

      if (mounted) {
        final msg = sharedToCommunity
            ? 'Resep disimpan & dibagikan ke komunitas!'
            : 'Resep berhasil disimpan!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.primary),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan resep. Coba lagi.')),
        );
      }
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
            _section('Foto Resep'),
            _buildImagePicker(),
            const SizedBox(height: 20),
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
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori', prefixIcon: Icon(Icons.category)),
              items: AppConstants.categories.skip(1).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _timeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Waktu (menit) *', prefixIcon: Icon(Icons.timer)),
                validator: (v) {
                  if (v?.trim().isEmpty == true) return 'Wajib diisi';
                  final n = int.tryParse(v!.trim());
                  if (n == null) return 'Harus berupa angka';
                  if (n <= 0) return 'Harus lebih dari 0';
                  return null;
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _servingsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Porsi *', prefixIcon: Icon(Icons.people)),
                validator: (v) {
                  if (v?.trim().isEmpty == true) return 'Wajib diisi';
                  final n = int.tryParse(v!.trim());
                  if (n == null) return 'Harus berupa angka';
                  if (n <= 0) return 'Harus lebih dari 0';
                  return null;
                },
              )),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Tingkat Kesulitan', prefixIcon: Icon(Icons.bar_chart)),
              items: AppConstants.difficulties.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _difficulty = v!),
            ),
            const SizedBox(height: 20),
            _section('Bahan-bahan'),
            ..._ingredientCtrls.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: TextFormField(
                  controller: e.value,
                  decoration: InputDecoration(
                    labelText: 'Bahan ${e.key + 1}',
                    prefixIcon: const Icon(Icons.fiber_manual_record, size: 12, color: AppTheme.primary),
                  ),
                )),
                if (_ingredientCtrls.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => setState(() {
                      _ingredientCtrls[e.key].dispose();
                      _ingredientCtrls.removeAt(e.key);
                    }),
                  ),
              ]),
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
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, right: 8),
                  child: CircleAvatar(radius: 14, backgroundColor: AppTheme.primary,
                    child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                ),
                Expanded(child: TextFormField(
                  controller: e.value,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: 'Langkah ${e.key + 1}'),
                )),
                if (_stepCtrls.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => setState(() {
                      _stepCtrls[e.key].dispose();
                      _stepCtrls.removeAt(e.key);
                    }),
                  ),
              ]),
            )),
            TextButton.icon(
              onPressed: () => setState(() => _stepCtrls.add(TextEditingController())),
              icon: const Icon(Icons.add, color: AppTheme.primary),
              label: const Text('Tambah Langkah', style: TextStyle(color: AppTheme.primary)),
            ),
            const SizedBox(height: 24),
            if (FirebaseAuth.instance.currentUser != null)
              Card(
                color: AppTheme.primary.withValues(alpha: 0.06),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: CheckboxListTile(
                  value: _shareToCommunity,
                  onChanged: (v) => setState(() => _shareToCommunity = v ?? false),
                  activeColor: AppTheme.primary,
                  title: const Text('Bagikan ke Komunitas', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Resep kamu bisa dilihat pengguna lain', style: TextStyle(fontSize: 12)),
                  secondary: const Icon(Icons.people, color: AppTheme.primary),
                  controlAffinity: ListTileControlAffinity.leading,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text(_savingMessage, style: const TextStyle(color: Colors.white)),
                    ])
                  : Text(
                      _shareToCommunity ? 'Simpan & Bagikan' : 'Simpan Resep',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasLocal = _localImagePath != null && File(_localImagePath!).existsSync();
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: hasLocal
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(fit: StackFit.expand, children: [
                  Image.file(File(_localImagePath!), fit: BoxFit.cover),
                  Container(color: Colors.black26, alignment: Alignment.center,
                    child: const Icon(Icons.edit, color: Colors.white, size: 32)),
                ]),
              )
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate, size: 48, color: AppTheme.primary),
                const SizedBox(height: 8),
                Text('Pilih foto dari galeri (opsional)', style: TextStyle(color: AppTheme.textSubOn(context))),
              ]),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textOn(context))),
  );
}
