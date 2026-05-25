import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import 'auth_gate_screen.dart';
import 'privacy_policy_screen.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import Backup'),
        content: const Text(
          'Resep dari file backup akan ditambahkan ke koleksi privat kamu.\n\n'
          'Resep yang sudah ada tidak akan ditimpa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

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
      await review.openStoreListing(appStoreId: 'com.resepin.resep_makanan');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
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
                    subtitle: const Text('Ekspor resep privat ke file JSON'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _doExport,
                  ),
                  ListTile(
                    leading: const Icon(Icons.download, color: AppTheme.primary),
                    title: const Text('Import Backup'),
                    subtitle: const Text('Tambah resep dari file backup (.json)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _doImport,
                  ),
                ]),
          _divider(),

          _buildAccountSection(context),
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
            leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.primary),
            title: const Text('Kebijakan Privasi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
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

  Widget _buildAccountSection(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isLoggedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Akun'),
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundImage: auth.user?.photoURL != null ? NetworkImage(auth.user!.photoURL!) : null,
              backgroundColor: AppTheme.primary,
              child: auth.user?.photoURL == null
                  ? const Icon(Icons.person, size: 18, color: Colors.white)
                  : null,
            ),
            title: Text(auth.user?.displayName ?? 'Pengguna', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(auth.user?.email ?? '', style: const TextStyle(fontSize: 12)),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Keluar', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Keluar dari akun Google'),
            onTap: () => _signOut(context),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Akun'),
        ListTile(
          leading: const Icon(Icons.login, color: AppTheme.primary),
          title: const Text('Masuk ke Komunitas'),
          subtitle: const Text('Login untuk berbagi dan menilai resep'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const AuthGateScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 350),
            ),
            (_) => false,
          ),
        ),
      ],
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari akun?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthGateScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
          (_) => false,
        );
      }
    }
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(title, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);
}
