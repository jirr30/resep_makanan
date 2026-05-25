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
import '../services/rating_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

// ── Structured ingredient entry ───────────────────────────────────────────────

class _IngEntry {
  final TextEditingController qtyCtrl  = TextEditingController();
  String unit = 'gram';
  final TextEditingController nameCtrl = TextEditingController();

  void dispose() {
    qtyCtrl.dispose();
    nameCtrl.dispose();
  }

  String formatted() {
    final qty  = qtyCtrl.text.trim();
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return '';
    if (unit == 'secukupnya') return '$name secukupnya';
    if (qty.isEmpty) return name;
    return '$qty $unit $name';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  static const _units = [
    'gram', 'kg', 'ml', 'liter',
    'sdm', 'sdt', 'cangkir',
    'buah', 'batang', 'siung', 'lembar',
    'bungkus', 'potong', 'secukupnya',
  ];

  static const _availableTags = [
    'Halal', 'Vegetarian', 'Vegan', 'Bebas Laktosa', 'Gluten Free',
    'Pedas', 'Rendah Kalori', 'Tinggi Protein', 'Keto', 'Ramadan',
  ];

  final _formKey      = GlobalKey<FormState>();
  final _db           = DatabaseService();
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _prepTimeCtrl = TextEditingController();
  final _cookTimeCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController();
  final _tipsCtrl     = TextEditingController();

  String _category   = AppConstants.categories[1];
  String _difficulty = AppConstants.difficulties[0];
  final List<_IngEntry> _ingEntries = [_IngEntry()];
  final List<TextEditingController> _stepCtrls = [TextEditingController()];
  final Set<String> _selectedTags = {};
  String? _localImagePath;
  bool _saving = false;
  String _savingMessage = '';
  bool _shareToCommunity = false;

  @override
  void dispose() {
    for (final c in [_titleCtrl, _descCtrl, _prepTimeCtrl, _cookTimeCtrl, _servingsCtrl, _tipsCtrl]) {
      c.dispose();
    }
    for (final e in _ingEntries) { e.dispose(); }
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

    final ingredients = _ingEntries
        .map((e) => e.formatted())
        .where((s) => s.isNotEmpty)
        .toList();
    if (ingredients.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 2 bahan')),
      );
      return;
    }

    final steps = _stepCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 langkah memasak')),
      );
      return;
    }

    setState(() { _saving = true; _savingMessage = 'Menghitung nutrisi...'; });

    final servings  = int.tryParse(_servingsCtrl.text) ?? 2;
    final prepTime  = int.tryParse(_prepTimeCtrl.text) ?? 0;
    final cookTime  = int.tryParse(_cookTimeCtrl.text) ?? 30;

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
      steps:       steps,
      cookingTime: cookTime,
      servings:    servings,
      difficulty:  _difficulty,
      prepTime:    prepTime,
      tags:        _selectedTags.toList(),
      tips:        _tipsCtrl.text.trim(),
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
        await RatingService.triggerAfterPositiveAction(context);
        if (mounted) Navigator.pop(context);
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
            // Prep time + Cook time
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
              Expanded(child: TextFormField(
                controller: _cookTimeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Masak (menit) *', prefixIcon: Icon(Icons.timer)),
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
            Row(children: [
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
            _buildIngredientHint(),
            const SizedBox(height: 8),
            ..._ingEntries.asMap().entries.map((e) => KeyedSubtree(
              key: ObjectKey(e.value),
              child: _buildIngredientRow(e.key, e.value),
            )),
            TextButton.icon(
              onPressed: () => setState(() => _ingEntries.add(_IngEntry())),
              icon: const Icon(Icons.add, color: AppTheme.primary),
              label: const Text('Tambah Bahan', style: TextStyle(color: AppTheme.primary)),
            ),

            const SizedBox(height: 20),
            _section('Langkah-langkah'),
            _buildStepsSection(),
            TextButton.icon(
              onPressed: () => setState(() => _stepCtrls.add(TextEditingController())),
              icon: const Icon(Icons.add, color: AppTheme.primary),
              label: const Text('Tambah Langkah', style: TextStyle(color: AppTheme.primary)),
            ),

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

  Widget _buildIngredientHint() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        'Jumlah  •  Satuan  •  Nama bahan',
        style: TextStyle(fontSize: 12, color: AppTheme.textSubOn(context)),
      ),
    );
  }

  Widget _buildIngredientRow(int index, _IngEntry entry) {
    final isSecukupnya = entry.unit == 'secukupnya';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Quantity — hidden when "secukupnya"
          if (!isSecukupnya)
            SizedBox(
              width: 56,
              child: TextFormField(
                controller: entry.qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: 'Jml',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                ),
              ),
            ),
          if (!isSecukupnya) const SizedBox(width: 6),
          // Unit dropdown — plain DropdownButton (reactive, no FormField state issues)
          SizedBox(
            width: isSecukupnya ? 110 : 96,
            child: InputDecorator(
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.fromLTRB(8, 11, 4, 11),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: entry.unit,
                  isDense: true,
                  isExpanded: true,
                  style: TextStyle(fontSize: 13, color: AppTheme.textOn(context)),
                  items: _units.map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setState(() => entry.unit = v!),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Name
          Expanded(
            child: TextFormField(
              controller: entry.nameCtrl,
              decoration: InputDecoration(
                hintText: 'Nama bahan ${index + 1}',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
            ),
          ),
          // Remove button
          if (_ingEntries.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
              onPressed: () => setState(() {
                _ingEntries[index].dispose();
                _ingEntries.removeAt(index);
              }),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
        ],
      ),
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
        final i    = e.key;
        final ctrl = e.value;
        return Padding(
          key: ObjectKey(ctrl),
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Expanded(
                child: TextFormField(
                  controller: e.value,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Langkah ${i + 1}',
                    hintText: 'Deskripsikan langkah ini...',
                  ),
                ),
              ),
              if (_stepCtrls.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () => setState(() {
                    _stepCtrls[i].dispose();
                    _stepCtrls.removeAt(i);
                  }),
                ),
            ],
          ),
        );
      }).toList(),
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
