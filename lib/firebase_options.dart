import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for ConnectGHIN (`connectghin-prod`).
class DefaultFirebaseOptions {
  /// Whether [currentPlatform] can be used on this device (Android only until iOS is configured).
  static bool get isConfigured {
    if (kIsWeb) {
      return false;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return true;
      case TargetPlatform.iOS:
        return false;
      default:
        return false;
    }
  }

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
    apiKey: 'AIzaSyCOWnaUQKevTgJg4ePWlI_ZzJ_o_L89xfU',
    appId: '1:97795397365:android:9d52692608fadb000757bc',
    messagingSenderId: '97795397365',
    projectId: 'connectghin-prod',
    storageBucket: 'connectghin-prod.firebasestorage.app',
  );
}
