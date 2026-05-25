import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
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
  final _backup = BackupService();
  final _db     = DatabaseService();

  String _version      = '';
  bool _notifEnabled   = true;
  bool _loadingBackup  = false;
  bool _loadingClear   = false;

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
        _version      = '${info.version}+${info.buildNumber}';
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

  // ── Backup ──────────────────────────────────────────────────────────────────

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

  // ── Clear data ──────────────────────────────────────────────────────────────

  Future<void> _doClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Semua Data Lokal'),
        content: const Text(
          'Semua resep privat, daftar belanja, meal plan, dan koleksi '
          'akan dihapus permanen dari perangkat ini.\n\n'
          'Resep yang sudah dipublikasikan ke komunitas tidak terpengaruh.\n\n'
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loadingClear = true);
    try {
      await _db.clearAllLocalData();
      _showSnack('Semua data lokal berhasil dihapus', isError: false);
    } catch (e) {
      _showSnack('Gagal menghapus data: $e');
    } finally {
      if (mounted) setState(() => _loadingClear = false);
    }
  }

  // ── Contact ─────────────────────────────────────────────────────────────────

  void _showContactSheet() {
    const email = 'amrmuhajir44@gmail.com';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderOn(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Hubungi / Laporkan Bug',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Temukan bug atau punya saran? Kirim email ke kami.',
              style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOn(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderOn(context)),
              ),
              child: Row(children: [
                const Icon(Icons.email_outlined, color: AppTheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(email,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Salin email',
                  color: AppTheme.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: email));
                    Navigator.pop(context);
                    _showSnack('Email disalin ke clipboard', isError: false);
                  },
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Text(
              'Sertakan versi aplikasi dan langkah untuk mereproduksi bug.',
              style: TextStyle(color: AppTheme.textSubOn(context), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ── Rating ───────────────────────────────────────────────────────────────────

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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [

          // ── Tampilan ──────────────────────────────────────────────────────────
          _sectionHeader('Tampilan'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tema Aplikasi',
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.textSubOn(context))),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor:
                        AppTheme.primary.withValues(alpha: 0.12),
                    selectedForegroundColor: AppTheme.primary,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('Sistem'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Terang'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Gelap'),
                    ),
                  ],
                  selected: {theme.mode},
                  onSelectionChanged: (s) => theme.setMode(s.first),
                ),
              ],
            ),
          ),
          _divider(),

          // ── Notifikasi ────────────────────────────────────────────────────────
          _sectionHeader('Notifikasi'),
          SwitchListTile(
            value: _notifEnabled,
            onChanged: _toggleNotif,
            title: const Text('Notifikasi Timer'),
            subtitle: const Text('Notifikasi saat timer memasak selesai'),
            secondary: const Icon(Icons.notifications_outlined,
                color: AppTheme.primary),
          ),
          _divider(),

          // ── Data ──────────────────────────────────────────────────────────────
          _sectionHeader('Data'),
          _loadingBackup
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()))
              : Column(children: [
                  ListTile(
                    leading: const Icon(Icons.upload_outlined,
                        color: AppTheme.primary),
                    title: const Text('Ekspor Backup'),
                    subtitle: const Text('Ekspor resep privat ke file JSON'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _doExport,
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_outlined,
                        color: AppTheme.primary),
                    title: const Text('Import Backup'),
                    subtitle:
                        const Text('Tambah resep dari file backup (.json)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _doImport,
                  ),
                ]),
          _loadingClear
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()))
              : ListTile(
                  leading:
                      const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                  title: const Text('Hapus Semua Data Lokal',
                      style: TextStyle(color: Colors.red)),
                  subtitle: const Text(
                      'Hapus resep privat, belanja, meal plan, koleksi'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.red),
                  onTap: _doClearData,
                ),
          _divider(),

          // ── Akun ──────────────────────────────────────────────────────────────
          _buildAccountSection(context),
          _divider(),

          // ── Tentang ───────────────────────────────────────────────────────────
          _sectionHeader('Tentang'),
          ListTile(
            leading: const Icon(Icons.star_rate_outlined, color: Colors.amber),
            title: const Text('Beri Rating'),
            subtitle: const Text('Bantu kami dengan memberikan rating'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _rateApp,
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined,
                color: AppTheme.primary),
            title: const Text('Hubungi / Laporkan Bug'),
            subtitle: const Text('Kirim masukan atau laporan masalah'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showContactSheet,
          ),
          ListTile(
            leading:
                const Icon(Icons.balance_outlined, color: AppTheme.primary),
            title: const Text('Lisensi Open Source'),
            subtitle: const Text('Library yang digunakan aplikasi ini'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'ResepKu',
              applicationVersion: _version,
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.privacy_tip_outlined, color: AppTheme.primary),
            title: const Text('Kebijakan Privasi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
          ),
          ListTile(
            leading:
                const Icon(Icons.info_outline, color: AppTheme.primary),
            title: const Text('Versi Aplikasi'),
            subtitle: Text(_version.isEmpty ? 'Memuat...' : _version),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Account section ──────────────────────────────────────────────────────────

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
              backgroundImage: auth.user?.photoURL != null
                  ? NetworkImage(auth.user!.photoURL!)
                  : null,
              backgroundColor: AppTheme.primary,
              child: auth.user?.photoURL == null
                  ? const Icon(Icons.person, size: 18, color: Colors.white)
                  : null,
            ),
            title: Text(auth.user?.displayName ?? 'Pengguna',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(auth.user?.email ?? '',
                style: const TextStyle(fontSize: 12)),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
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
        child: Text(title,
            style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);
}
