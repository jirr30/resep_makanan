import 'dart:io';
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

class EditRecipeScreen extends StatefulWidget {
  final Recipe recipe;
  const EditRecipeScreen({super.key, required this.recipe});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  static const _availableTags = [
    'Halal', 'Vegetarian', 'Vegan', 'Bebas Laktosa', 'Gluten Free',
    'Pedas', 'Rendah Kalori', 'Tinggi Protein', 'Keto', 'Ramadan',
  ];

  final _formKey = GlobalKey<FormState>();
  final _db      = DatabaseService();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _imageCtrl;
  late TextEditingController _prepTimeCtrl;
  late TextEditingController _cookTimeCtrl;
  late TextEditingController _servingsCtrl;
  late TextEditingController _tipsCtrl;
  late String _category;
  late String _difficulty;
  late List<TextEditingController> _ingredientCtrls;
  late List<TextEditingController> _stepCtrls;
  late Set<String> _selectedTags;
  String? _localImagePath;
  bool _saving = false;
  String _savingMessage = '';

  @override
  void initState() {
    super.initState();
    final r       = widget.recipe;
    _titleCtrl    = TextEditingController(text: r.title);
    _descCtrl     = TextEditingController(text: r.description);
    _imageCtrl    = TextEditingController(text: r.imageUrl);
    _prepTimeCtrl = TextEditingController(text: r.prepTime > 0 ? r.prepTime.toString() : '');
    _cookTimeCtrl = TextEditingController(text: r.cookingTime.toString());
    _servingsCtrl = TextEditingController(text: r.servings.toString());
    _tipsCtrl     = TextEditingController(text: r.tips);
    _category     = AppConstants.categories.contains(r.category) ? r.category : AppConstants.categories[1];
    _difficulty   = r.difficulty;
    _localImagePath  = r.imagePath;
    _selectedTags    = Set<String>.from(r.tags);
    _ingredientCtrls = r.ingredients.map((s) => TextEditingController(text: s)).toList();
    _stepCtrls       = r.steps.map((s) => TextEditingController(text: s)).toList();
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _descCtrl, _imageCtrl, _prepTimeCtrl, _cookTimeCtrl, _servingsCtrl, _tipsCtrl]) {
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

    final ingredients = _ingredientCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (ingredients.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 2 bahan')),
      );
      return;
    }

    final steps = _stepCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 langkah memasak')),
      );
      return;
    }

    setState(() { _saving = true; _savingMessage = 'Menghitung nutrisi...'; });

    final servings = int.tryParse(_servingsCtrl.text) ?? widget.recipe.servings;
    final prepTime = int.tryParse(_prepTimeCtrl.text) ?? 0;
    final cookTime = int.tryParse(_cookTimeCtrl.text) ?? widget.recipe.cookingTime;

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
    setState(() => _savingMessage = 'Menyimpan perubahan...');

    final updated = Recipe(
      id:           widget.recipe.id,
      firestoreId:  widget.recipe.firestoreId,
      title:        _titleCtrl.text.trim(),
      category:     _category,
      description:  _descCtrl.text.trim(),
      imageUrl:     _imageCtrl.text.trim(),
      imagePath:    _localImagePath,
      ingredients:  ingredients,
      steps:        steps,
      cookingTime:  cookTime,
      servings:     servings,
      rating:       widget.recipe.rating,
      userRating:   widget.recipe.userRating,
      difficulty:   _difficulty,
      isFavorite:   widget.recipe.isFavorite,
      isOwned:      widget.recipe.isOwned,
      calories:     nutrition?.calories ?? widget.recipe.calories,
      protein:      nutrition?.protein  ?? widget.recipe.protein,
      carbs:        nutrition?.carbs    ?? widget.recipe.carbs,
      fat:          nutrition?.fat      ?? widget.recipe.fat,
      prepTime:     prepTime,
      tags:         _selectedTags.toList(),
      tips:         _tipsCtrl.text.trim(),
    );

    try {
      await _db.updateRecipe(updated);

      if (updated.firestoreId != null) {
        if (mounted) setState(() => _savingMessage = 'Sinkronisasi ke komunitas...');
        try {
          await FirestoreService().updateCommunityRecipe(updated.firestoreId!, updated);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resep berhasil diperbarui!'), backgroundColor: AppTheme.primary),
        );
        Navigator.pop(context, updated);
      }
    } catch (_) {
      if (mounted) {
        setState(() { _saving = false; _savingMessage = ''; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan perubahan. Coba lagi.'), backgroundColor: Colors.red),
        );
      }
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
              initialValue: AppConstants.categories.skip(1).contains(_category) ? _category : AppConstants.categories[1],
              decoration: const InputDecoration(labelText: 'Kategori', prefixIcon: Icon(Icons.category)),
              items: AppConstants.categories.skip(1).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _prepTimeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Persiapan (menit)',
                  prefixIcon: Icon(Icons.hourglass_empty),
                  hintText: 'Opsional',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 0) return 'Harus angka ≥ 0';
                  return null;
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: _field(_cookTimeCtrl, 'Masak (menit) *', Icons.timer, required: true, numeric: true)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_servingsCtrl, 'Porsi *', Icons.people, required: true, numeric: true)),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: const InputDecoration(labelText: 'Kesulitan', prefixIcon: Icon(Icons.bar_chart)),
                items: AppConstants.difficulties.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setState(() => _difficulty = v!),
              )),
            ]),

            const SizedBox(height: 20),
            _section('Tags Resep'),
            _buildTagsSection(),

            const SizedBox(height: 20),
            _section('Bahan-bahan'),
            ..._ingredientCtrls.asMap().entries.map((e) => _dynamicField(
              e.value, 'Bahan ${e.key + 1}',
              onRemove: _ingredientCtrls.length > 1
                  ? () => setState(() { _ingredientCtrls[e.key].dispose(); _ingredientCtrls.removeAt(e.key); })
                  : null,
            )),
            _addBtn('Tambah Bahan', () => setState(() => _ingredientCtrls.add(TextEditingController()))),

            const SizedBox(height: 20),
            _section('Langkah-langkah'),
            _buildStepsSection(),
            _addBtn('Tambah Langkah', () => setState(() => _stepCtrls.add(TextEditingController()))),

            const SizedBox(height: 20),
            _section('Tips Memasak (Opsional)'),
            TextFormField(
              controller: _tipsCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Tips, variasi, atau catatan tambahan',
                prefixIcon: Icon(Icons.lightbulb_outline, color: Colors.amber),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text(_savingMessage, style: const TextStyle(color: Colors.white)),
                    ])
                  : const Text('Simpan Perubahan', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _availableTags.map((tag) {
        final selected = _selectedTags.contains(tag);
        return FilterChip(
          label: Text(tag),
          selected: selected,
          onSelected: (sel) => setState(() {
            if (sel) { _selectedTags.add(tag); } else { _selectedTags.remove(tag); }
          }),
          selectedColor: AppTheme.primary.withValues(alpha: 0.15),
          checkmarkColor: AppTheme.primary,
          labelStyle: TextStyle(
            color: selected ? AppTheme.primary : AppTheme.textSubOn(context),
            fontSize: 13,
          ),
          side: BorderSide(
            color: selected ? AppTheme.primary : Colors.grey.shade300,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepsSection() {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final ctrl = _stepCtrls.removeAt(oldIndex);
          _stepCtrls.insert(newIndex, ctrl);
        });
      },
      children: _stepCtrls.asMap().entries.map((e) {
        final i = e.key;
        return Padding(
          key: ValueKey(i),
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ReorderableDragStartListener(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(top: 14, right: 8),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primary,
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ),
            Expanded(child: TextFormField(
              controller: e.value,
              maxLines: 2,
              decoration: InputDecoration(labelText: 'Langkah ${i + 1}'),
            )),
            if (_stepCtrls.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () => setState(() {
                  _stepCtrls[i].dispose();
                  _stepCtrls.removeAt(i);
                }),
              ),
          ]),
        );
      }).toList(),
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
                Text('Ketuk untuk pilih foto dari galeri', style: TextStyle(color: AppTheme.textSubOn(context))),
                const SizedBox(height: 4),
                Text('(atau gunakan URL gambar di bawah)', style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 12)),
              ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {bool required = false, bool numeric = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: required
          ? (v) {
              if (v?.trim().isEmpty == true) return 'Wajib diisi';
              if (numeric) {
                final n = int.tryParse(v!.trim());
                if (n == null) return 'Harus berupa angka';
                if (n <= 0) return 'Harus lebih dari 0';
              }
              return null;
            }
          : null,
    );
  }

  Widget _dynamicField(TextEditingController ctrl, String label, {VoidCallback? onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: TextFormField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.fiber_manual_record, size: 12, color: AppTheme.primary),
          ),
        )),
        if (onRemove != null)
          IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: onRemove),
      ]),
    );
  }

  Widget _addBtn(String label, VoidCallback onTap) => TextButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add, color: AppTheme.primary),
    label: Text(label, style: const TextStyle(color: AppTheme.primary)),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textOn(context))),
  );
}
