import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../firebase_options.dart';
import 'push_navigation.dart';

typedef PushMessageHandler = void Function(RemoteMessage message);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isConfigured) {
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Initializes FCM and exposes the device token for backend registration.
class PushNotifications {
  PushNotifications._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;
  static GoRouter? _router;
  static PushMessageHandler? _onForegroundMessage;

  /// True when Firebase options exist for this platform (Android today; iOS when configured).
  static bool get isSupported => DefaultFirebaseOptions.isConfigured;

  static void attach({
    required GoRouter router,
    PushMessageHandler? onForegroundMessage,
  }) {
    _router = router;
    _onForegroundMessage = onForegroundMessage;
  }

  static Future<void> init() async {
    if (_initialized || !isSupported) {
      return;
    }
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen(_handleForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);

    _initialized = true;
  }

  /// Call after [GoRouter] is ready (e.g. first frame) to handle cold-start notification taps.
  static Future<void> handleLaunchNotification() async {
    if (!isSupported) {
      return;
    }
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleOpened(initial);
    }
  }

  static Future<bool> requestPermission() async {
    if (!isSupported) {
      return false;
    }
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (Platform.isAndroid) {
      return true;
    }
    final status = settings.authorizationStatus;
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  static Future<String?> getToken() async {
    if (!isSupported) {
      return null;
    }
    return _messaging.getToken();
  }

  static Stream<String> get onTokenRefresh {
    if (!isSupported) {
      return const Stream<String>.empty();
    }
    return _messaging.onTokenRefresh;
  }

  static String platformName() {
    if (Platform.isIOS) {
      return 'IOS';
    }
    if (Platform.isAndroid) {
      return 'ANDROID';
    }
    return 'WEB';
  }

  static void _handleForeground(RemoteMessage message) {
    debugPrint('FCM foreground: ${message.notification?.title}');
    _onForegroundMessage?.call(message);
  }

  static void _handleOpened(RemoteMessage message) {
    debugPrint('FCM opened app: ${message.data}');
    final router = _router;
    if (router == null) {
      return;
    }
    PushNavigation.navigateFromMessage(router, message);
  }
}
