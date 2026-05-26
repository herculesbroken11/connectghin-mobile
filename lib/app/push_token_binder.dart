import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/notifications/data/notifications_api.dart';
import 'session/auth_session.dart';
import '../core/push/push_notifications.dart';
import '../core/push/push_token_registry.dart';

/// Registers the FCM device token with the backend while logged in.
class PushTokenBinder extends StatefulWidget {
  const PushTokenBinder({super.key, required this.child});

  final Widget child;

  @override
  State<PushTokenBinder> createState() => _PushTokenBinderState();
}

class _PushTokenBinderState extends State<PushTokenBinder> {
  late final AuthSession _session;
  late final VoidCallback _authListener;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _accessToken;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _session = context.read<AuthSession>();
    _authListener = () => _syncFromSession(_session);
    _session.addListener(_authListener);
    if (PushNotifications.isSupported) {
      _tokenRefreshSub = PushNotifications.onTokenRefresh.listen(_onTokenRefresh);
    }
    PushTokenRegistry.resync = () => _syncFromSession(_session, force: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromSession(_session));
  }

  @override
  void dispose() {
    PushTokenRegistry.resync = null;
    _tokenRefreshSub?.cancel();
    _session.removeListener(_authListener);
    super.dispose();
  }

  Future<void> _onTokenRefresh(String newToken) async {
    _fcmToken = newToken;
    final access = _session.accessToken;
    if (access == null || access.isEmpty) {
      return;
    }
    await _register(access, newToken);
  }

  Future<void> _syncFromSession(AuthSession session, {bool force = false}) async {
    if (!mounted || !PushNotifications.isSupported) {
      return;
    }
    final access = session.accessToken;
    if (access == null || access.isEmpty) {
      final previousAccess = _accessToken;
      final previousFcm = _fcmToken;
      _accessToken = null;
      _fcmToken = null;
      if (previousAccess != null &&
          previousAccess.isNotEmpty &&
          previousFcm != null &&
          previousFcm.isNotEmpty) {
        await _unregister(previousAccess, previousFcm);
      }
      return;
    }
    if (!force && access == _accessToken && _fcmToken != null) {
      return;
    }
    _accessToken = access;
    final fcm = await PushNotifications.getToken();
    if (fcm == null || fcm.isEmpty) {
      return;
    }
    if (fcm == _fcmToken && !force) {
      return;
    }
    _fcmToken = fcm;
    await _register(access, fcm);
  }

  Future<void> _register(String accessToken, String fcmToken) async {
    try {
      await NotificationsApi(_session.apiClient).registerToken(
        accessToken: accessToken,
        platform: PushNotifications.platformName(),
        token: fcmToken,
      );
    } catch (e) {
      debugPrint('FCM register-token failed: $e');
    }
  }

  Future<void> _unregister(String accessToken, String fcmToken) async {
    try {
      await NotificationsApi(_session.apiClient).unregisterToken(
        accessToken: accessToken,
        token: fcmToken,
      );
    } catch (e) {
      debugPrint('FCM unregister-token failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
