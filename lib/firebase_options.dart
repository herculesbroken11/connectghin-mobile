import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for ConnectGHIN (`connectghin-6e881`).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is not configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Firebase is not configured for iOS yet. Add GoogleService-Info.plist and run FlutterFire configure.',
        );
      default:
        throw UnsupportedError(
          'Firebase is not supported on $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCHSzlcD4k5eNzyySL91Dc3alrsD0RWsE4',
    appId: '1:628563228753:android:109b85ea5ce1d060c2a070',
    messagingSenderId: '628563228753',
    projectId: 'connectghin-6e881',
    storageBucket: 'connectghin-6e881.firebasestorage.app',
  );
}
