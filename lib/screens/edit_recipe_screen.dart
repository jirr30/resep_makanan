import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../services/nutrition_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class EditRecipeScreen extends StatefulWidget {
  final Recipe recipe;
  const EditRecipeScreen({super.key, required this.recipe});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _imageCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _servingsCtrl;
  late TextEditingController _calCtrl;
  late TextEditingController _proteinCtrl;
  late TextEditingController _carbsCtrl;
  late TextEditingController _fatCtrl;

  late String _category;
  late String _difficulty;
  late List<TextEditingController> _ingredientCtrls;
  late List<TextEditingController> _stepCtrls;
  String? _localImagePath;
  bool _saving = false;
  bool _calculatingNutrition = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _titleCtrl    = TextEditingController(text: r.title);
    _descCtrl     = TextEditingController(text: r.description);
    _imageCtrl    = TextEditingController(text: r.imageUrl);
    _timeCtrl     = TextEditingController(text: r.cookingTime.toString());
    _servingsCtrl = TextEditingController(text: r.servings.toString());
    _calCtrl      = TextEditingController(text: r.calories == 0 ? '' : r.calories.toString());
    _proteinCtrl  = TextEditingController(text: r.protein == 0 ? '' : r.protein.toString());
    _carbsCtrl    = TextEditingController(text: r.carbs == 0 ? '' : r.carbs.toString());
    _fatCtrl      = TextEditingController(text: r.fat == 0 ? '' : r.fat.toString());
    _category     = AppConstants.categories.contains(r.category) ? r.category : AppConstants.categories[1];
    _difficulty   = r.difficulty;
    _localImagePath = r.imagePath;
    _ingredientCtrls = r.ingredients.map((s) => TextEditingController(text: s)).toList();
    _stepCtrls       = r.steps.map((s) => TextEditingController(text: s)).toList();
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _descCtrl, _imageCtrl, _timeCtrl, _servingsCtrl,
      _calCtrl, _proteinCtrl, _carbsCtrl, _fatCtrl]) { c.dispose(); }
    for (final c in _ingredientCtrls) { c.dispose(); }
    for (final c in _stepCtrls) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final name = 'recipe_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
    final saved = await File(picked.path).copy('${dir.path}/$name');
    setState(() => _localImagePath = saved.path);
  }

  Future<void> _calculateNutrition() async {
    final ingredients = _ingredientCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi bahan-bahan terlebih dahulu')),
      );
      return;
    }
    setState(() => _calculatingNutrition = true);
    try {
      final servings = int.tryParse(_servingsCtrl.text) ?? widget.recipe.servings;
      final result = await NutritionService().estimateFromIngredients(
        ingredients: ingredients,
        servings: servings,
      );
      if (!mounted) return;
      setState(() {
        _calCtrl.text     = result.calories.toString();
        _proteinCtrl.text = result.protein.toStringAsFixed(1);
        _carbsCtrl.text   = result.carbs.toStringAsFixed(1);
        _fatCtrl.text     = result.fat.toStringAsFixed(1);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nutrisi berhasil dihitung!'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghitung nutrisi: $e')),
      );
    } finally {
      if (mounted) setState(() => _calculatingNutrition = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final updated = Recipe(
      id: widget.recipe.id,
      title: _titleCtrl.text.trim(),
      category: _category,
      description: _descCtrl.text.trim(),
      imageUrl: _imageCtrl.text.trim(),
      imagePath: _localImagePath,
      ingredients: _ingredientCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
      steps: _stepCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
      cookingTime: int.tryParse(_timeCtrl.text) ?? widget.recipe.cookingTime,
      servings: int.tryParse(_servingsCtrl.text) ?? widget.recipe.servings,
      rating: widget.recipe.rating,
      userRating: widget.recipe.userRating,
      difficulty: _difficulty,
      isFavorite: widget.recipe.isFavorite,
      calories: int.tryParse(_calCtrl.text) ?? 0,
      protein: double.tryParse(_proteinCtrl.text) ?? 0,
      carbs: double.tryParse(_carbsCtrl.text) ?? 0,
      fat: double.tryParse(_fatCtrl.text) ?? 0,
    );
    await _db.updateRecipe(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resep berhasil diperbarui!'), backgroundColor: AppTheme.primary),
      );
      Navigator.pop(context, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Resep')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Foto Resep'),
            _buildImagePicker(),
            const SizedBox(height: 20),
            _section('Informasi Dasar'),
            _field(_titleCtrl, 'Nama Resep *', Icons.restaurant_menu, required: true),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Deskripsi *', prefixIcon: Icon(Icons.description)),
              validator: (v) => v?.trim().isEmpty == true ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: AppConstants.categories.skip(1).contains(_category) ? _category : AppConstants.categories[1],
              decoration: const InputDecoration(labelText: 'Kategori', prefixIcon: Icon(Icons.category)),
              items: AppConstants.categories.skip(1).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_timeCtrl, 'Waktu (menit) *', Icons.timer, required: true, numeric: true)),
              const SizedBox(width: 12),
              Expanded(child: _field(_servingsCtrl, 'Porsi *', Icons.people, required: true, numeric: true)),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _difficulty,
              decoration: const InputDecoration(labelText: 'Kesulitan', prefixIcon: Icon(Icons.bar_chart)),
              items: AppConstants.difficulties.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _difficulty = v!),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _section('Informasi Nutrisi (per porsi)'),
                _calculatingNutrition
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      )
                    : TextButton.icon(
                        onPressed: _calculateNutrition,
                        icon: const Icon(Icons.auto_awesome, size: 16, color: AppTheme.primary),
                        label: const Text('Hitung Otomatis', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                      ),
              ],
            ),
            Row(children: [
              Expanded(child: _field(_calCtrl, 'Kalori (kkal)', Icons.local_fire_department, numeric: true)),
              const SizedBox(width: 12),
              Expanded(child: _field(_proteinCtrl, 'Protein (g)', Icons.egg, numeric: true)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_carbsCtrl, 'Karbo (g)', Icons.grain, numeric: true)),
              const SizedBox(width: 12),
              Expanded(child: _field(_fatCtrl, 'Lemak (g)', Icons.opacity, numeric: true)),
            ]),
            const SizedBox(height: 20),
            _section('Bahan-bahan'),
            ..._ingredientCtrls.asMap().entries.map((e) => _dynamicField(
              e.value, 'Bahan ${e.key + 1}',
              onRemove: _ingredientCtrls.length > 1 ? () => setState(() { _ingredientCtrls[e.key].dispose(); _ingredientCtrls.removeAt(e.key); }) : null,
            )),
            _addBtn('Tambah Bahan', () => setState(() => _ingredientCtrls.add(TextEditingController()))),
            const SizedBox(height: 20),
            _section('Langkah-langkah'),
            ..._stepCtrls.asMap().entries.map((e) => _stepField(e.key, e.value,
              onRemove: _stepCtrls.length > 1 ? () => setState(() { _stepCtrls[e.key].dispose(); _stepCtrls.removeAt(e.key); }) : null,
            )),
            _addBtn('Tambah Langkah', () => setState(() => _stepCtrls.add(TextEditingController()))),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16)),
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
        height: 180,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), style: BorderStyle.solid),
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
                const Text('Ketuk untuk pilih foto dari galeri', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                const Text('(atau gunakan URL gambar di bawah)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {bool required = false, bool numeric = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: required ? (v) => v?.trim().isEmpty == true ? 'Wajib diisi' : null : null,
    );
  }

  Widget _dynamicField(TextEditingController ctrl, String label, {VoidCallback? onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: TextFormField(controller: ctrl, decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.fiber_manual_record, size: 12, color: AppTheme.primary),
        ))),
        if (onRemove != null) IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: onRemove),
      ]),
    );
  }

  Widget _stepField(int index, TextEditingController ctrl, {VoidCallback? onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, right: 8),
          child: CircleAvatar(radius: 14, backgroundColor: AppTheme.primary,
            child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
        ),
        Expanded(child: TextFormField(controller: ctrl, maxLines: 2,
          decoration: InputDecoration(labelText: 'Langkah ${index + 1}'))),
        if (onRemove != null) IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: onRemove),
      ]),
    );
  }

  Widget _addBtn(String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, color: AppTheme.primary),
      label: Text(label, style: const TextStyle(color: AppTheme.primary)),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
  );
}
