import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Initializes FCM and exposes the device token for backend registration.
class PushNotifications {
  PushNotifications._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _messaging.requestPermission();
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM opened app: ${message.data}');
    });
    _initialized = true;
  }

  static Future<String?> getToken() => _messaging.getToken();

  static Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  static String platformName() {
    if (Platform.isIOS) {
      return 'IOS';
    }
    if (Platform.isAndroid) {
      return 'ANDROID';
    }
    return 'WEB';
  }
}
