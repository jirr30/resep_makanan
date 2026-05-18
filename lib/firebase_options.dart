import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform tidak didukung');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC13bQo6aIeJjWcP3gz-smZ6-IXppjHm_k',
    appId: '1:675950922875:android:e900e4e784c96afbfa66de',
    messagingSenderId: '675950922875',
    projectId: 'luay-ismi',
    storageBucket: 'luay-ismi.firebasestorage.app',
    databaseURL: 'https://luay-ismi-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
