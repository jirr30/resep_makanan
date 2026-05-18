import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _google = GoogleSignIn();

  Future<User?> signInWithGoogle() async {
    // Pastikan tidak ada sesi Google yang menggantung
    await _google.signOut();

    final googleUser = await _google.signIn();
    if (googleUser == null) return null; // user membatalkan login

    final googleAuth = await googleUser.authentication;

    if (googleAuth.idToken == null) {
      debugPrint('[AuthService] idToken null — SHA-1 belum didaftarkan di Firebase?');
      throw const AuthException(
        'Konfigurasi login belum lengkap. Hubungi developer.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
