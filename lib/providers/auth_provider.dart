import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  User? _user;
  bool _loading = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;

  AuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen((u) {
      _user = u;
      notifyListeners();
    });
  }

  Future<bool> signInWithGoogle() async {
    _loading = true;
    notifyListeners();
    try {
      _user = await _authService.signInWithGoogle();
      return _user != null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }
}
