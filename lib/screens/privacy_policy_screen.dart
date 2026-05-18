import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kebijakan Privasi')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header('Kebijakan Privasi ResepKu'),
            _Body('Terakhir diperbarui: 18 Mei 2026'),
            SizedBox(height: 16),
            _Body(
              'ResepKu ("kami") berkomitmen untuk melindungi privasi pengguna. '
              'Kebijakan ini menjelaskan data yang kami kumpulkan, cara penggunaannya, '
              'dan hak-hak Anda sebagai pengguna.',
            ),

            SizedBox(height: 24),
            _Section('1. Data yang Kami Kumpulkan'),
            _Bullet('Informasi akun Google (nama, email, foto profil) saat Anda login dengan Google.'),
            _Bullet('Resep yang Anda buat dan simpan secara lokal di perangkat Anda.'),
            _Bullet('Resep komunitas yang Anda publikasikan, termasuk foto yang diunggah.'),
            _Bullet('Rating dan suka (like) yang Anda berikan pada resep komunitas.'),
            _Bullet('Pengaturan aplikasi seperti preferensi tampilan dan notifikasi.'),

            SizedBox(height: 24),
            _Section('2. Cara Kami Menggunakan Data'),
            _Bullet('Menampilkan dan menyimpan resep pribadi Anda di perangkat (SQLite lokal).'),
            _Bullet('Memungkinkan fitur komunitas: berbagi resep, rating, dan like antar pengguna.'),
            _Bullet('Menghitung estimasi nutrisi menggunakan layanan Gemini AI dari Google.'),
            _Bullet('Mengirim notifikasi timer memasak sesuai pengaturan Anda.'),

            SizedBox(height: 24),
            _Section('3. Penyimpanan & Keamanan Data'),
            _Bullet('Data resep lokal disimpan di perangkat Anda dan tidak dikirim ke server tanpa izin.'),
            _Bullet('Data komunitas (resep yang dipublikasikan, foto) disimpan di Firebase/Google Cloud.'),
            _Bullet('Foto yang diunggah ke komunitas disimpan di Firebase Storage.'),
            _Bullet('Kami menggunakan layanan Firebase yang mematuhi standar keamanan Google.'),

            SizedBox(height: 24),
            _Section('4. Berbagi Data dengan Pihak Ketiga'),
            _Bullet('Google Firebase — untuk autentikasi, database komunitas, dan penyimpanan foto.'),
            _Bullet('Google Gemini AI — untuk estimasi nutrisi (hanya daftar bahan dikirim, tanpa data pribadi).'),
            _Bullet('Kami tidak menjual, menyewakan, atau membagikan data pribadi Anda kepada pihak lain.'),

            SizedBox(height: 24),
            _Section('5. Izin Perangkat yang Digunakan'),
            _Bullet('Galeri / Media — untuk memilih foto resep dari perangkat Anda.'),
            _Bullet('Notifikasi — untuk mengirim pengingat timer memasak.'),
            _Bullet('Internet — untuk fitur komunitas, login Google, dan estimasi nutrisi AI.'),

            SizedBox(height: 24),
            _Section('6. Hak Pengguna'),
            _Bullet('Anda dapat menghapus resep komunitas yang Anda publikasikan kapan saja.'),
            _Bullet('Anda dapat keluar (sign out) dari akun Google melalui menu Pengaturan.'),
            _Bullet('Anda dapat menghapus aplikasi untuk menghapus semua data lokal.'),
            _Bullet('Untuk permintaan penghapusan data komunitas, hubungi kami melalui email di bawah.'),

            SizedBox(height: 24),
            _Section('7. Kontak'),
            _Body(
              'Jika Anda memiliki pertanyaan atau permintaan terkait privasi, '
              'hubungi kami di: resepku.app@gmail.com',
            ),

            SizedBox(height: 24),
            _Body(
              'Dengan menggunakan aplikasi ResepKu, Anda menyetujui kebijakan privasi ini. '
              'Kami dapat memperbarui kebijakan ini sewaktu-waktu dan akan '
              'memberitahukan perubahan melalui pembaruan aplikasi.',
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      );
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textSecondary,
          height: 1.6,
        ),
      );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: CircleAvatar(radius: 3, backgroundColor: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
}
