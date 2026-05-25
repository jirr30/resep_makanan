import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_service.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final _db = DatabaseService();

  // ── Export ────────────────────────────────────────────────────────────────────

  Future<String> exportBackup() async {
    final rawData = await _db.exportAllData();

    // Sanitize: hapus field device-specific dan deprecated sebelum export
    final cleaned = rawData.map((row) {
      final m = Map<String, dynamic>.from(row);
      m.remove('id');          // SQLite auto-increment, tidak relevan di device lain
      m.remove('imagePath');   // path lokal device, tidak valid di device lain
      m.remove('isFavorite');  // fitur deprecated
      return m;
    }).toList();

    final json = jsonEncode({
      'version':    4,
      'exportedAt': DateTime.now().toIso8601String(),
      'recipes':    cleaned,
    });

    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/resepku_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], subject: 'Backup ResepKu');
    return file.path;
  }

  // ── Import ────────────────────────────────────────────────────────────────────

  Future<int> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return -1;
    final path = result.files.single.path;
    if (path == null) return -1;

    final content = await File(path).readAsString();
    final dynamic decoded = jsonDecode(content);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format file tidak valid');
    }
    final dynamic rawList = decoded['recipes'];
    if (rawList is! List) {
      throw const FormatException('File backup tidak mengandung data resep');
    }

    // Validasi tiap record sebelum import — tolak yang tidak valid
    final valid = rawList
        .whereType<Map<String, dynamic>>()
        .where(_isValidRecipe)
        .toList();

    if (valid.isEmpty) {
      throw const FormatException('Tidak ada resep valid dalam file backup');
    }

    await _db.importRecipes(valid);
    return valid.length;
  }

  // ── Validation ────────────────────────────────────────────────────────────────

  bool _isValidRecipe(Map<String, dynamic> r) {
    // Field string wajib tidak boleh kosong
    for (final key in ['title', 'category', 'description', 'difficulty']) {
      final v = r[key];
      if (v is! String || v.trim().isEmpty) return false;
    }
    // imageUrl wajib ada (boleh string kosong — akan pakai placeholder)
    if (r['imageUrl'] is! String) return false;
    // ingredients & steps disimpan sebagai string '||'-joined, wajib tidak kosong
    for (final key in ['ingredients', 'steps']) {
      final v = r[key];
      if (v is! String || v.trim().isEmpty) return false;
    }
    // Field numerik wajib positif
    final cookingTime = r['cookingTime'];
    if (cookingTime is! int || cookingTime <= 0) return false;
    final servings = r['servings'];
    if (servings is! int || servings <= 0) return false;
    return true;
  }
}
