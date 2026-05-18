import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _backup  = BackupService();
  String _version = '';
  bool _notifEnabled = true;
  bool _loadingBackup = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info  = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
        _notifEnabled = prefs.getBool('notif_enabled') ?? true;
      });
    }
  }

  Future<void> _toggleNotif(bool value) async {
    setState(() => _notifEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', value);
    if (!value) await NotificationService().cancelAll();
  }

  Future<void> _doExport() async {
    setState(() => _loadingBackup = true);
    try {
      await _backup.exportBackup();
      _showSnack('Backup berhasil diekspor!', isError: false);
    } catch (e) {
      _showSnack('Gagal ekspor: $e');
    } finally {
      if (mounted) setState(() => _loadingBackup = false);
    }
  }

  Future<void> _doImport() async {
    setState(() => _loadingBackup = true);
    try {
      final count = await _backup.importBackup();
      if (count == -1) {
        _showSnack('Import dibatalkan');
      } else {
        _showSnack('$count resep berhasil diimport!', isError: false);
      }
    } catch (e) {
      _showSnack('Gagal import: $e');
    } finally {
      if (mounted) setState(() => _loadingBackup = false);
    }
  }

  Future<void> _rateApp() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    } else {
      await review.openStoreListing(appStoreId: 'com.resepku.resep_makanan');
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : AppTheme.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          _sectionHeader('Tampilan'),
          SwitchListTile(
            value: themeProvider.isDark,
            onChanged: (_) => themeProvider.toggle(),
            title: const Text('Mode Gelap'),
            subtitle: const Text('Aktifkan tema dark mode'),
            secondary: Icon(themeProvider.isDark ? Icons.dark_mode : Icons.light_mode, color: AppTheme.primary),
          ),
          _divider(),

          _sectionHeader('Notifikasi'),
          SwitchListTile(
            value: _notifEnabled,
            onChanged: _toggleNotif,
            title: const Text('Notifikasi Timer'),
            subtitle: const Text('Notifikasi saat timer memasak selesai'),
            secondary: const Icon(Icons.notifications, color: AppTheme.primary),
          ),
          _divider(),

          _sectionHeader('Data'),
          _loadingBackup
              ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
              : Column(children: [
                  ListTile(
                    leading: const Icon(Icons.upload, color: AppTheme.primary),
                    title: const Text('Ekspor Backup'),
                    subtitle: const Text('Simpan semua resep ke file JSON'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _doExport,
                  ),
                  ListTile(
                    leading: const Icon(Icons.download, color: AppTheme.primary),
                    title: const Text('Import Backup'),
                    subtitle: const Text('Pulihkan resep dari file backup'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _doImport,
                  ),
                ]),
          _divider(),

          _sectionHeader('Tentang'),
          ListTile(
            leading: const Icon(Icons.star_rate, color: Colors.amber),
            title: const Text('Beri Rating'),
            subtitle: const Text('Bantu kami dengan memberikan rating'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _rateApp,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppTheme.primary),
            title: const Text('Versi Aplikasi'),
            subtitle: Text(_version.isEmpty ? 'Memuat...' : _version),
          ),
          ListTile(
            leading: const Icon(Icons.restaurant_menu, color: AppTheme.primary),
            title: const Text('ResepKu'),
            subtitle: const Text('Aplikasi Resep Masakan Indonesia'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(title, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);
}
