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

  Future<String> exportBackup() async {
    final data = await _db.exportAllData();
    final json = jsonEncode({'version': 3, 'exportedAt': DateTime.now().toIso8601String(), 'recipes': data});
    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/resepku_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], subject: 'Backup ResepKu');
    return file.path;
  }

  Future<int> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return -1;
    final path = result.files.single.path;
    if (path == null) return -1;
    final content = await File(path).readAsString();
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final recipes = (decoded['recipes'] as List).cast<Map<String, dynamic>>();
    await _db.importRecipes(recipes);
    return recipes.length;
  }
}
