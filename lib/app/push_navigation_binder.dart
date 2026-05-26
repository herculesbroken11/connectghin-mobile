import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/network/api_user_message.dart';
import '../core/push/push_notifications.dart';
import '../features/messages/data/inbox_realtime_tick.dart';

/// Wires FCM tap / foreground handlers to [GoRouter] and inbox refresh.
class PushNavigationBinder extends StatefulWidget {
  const PushNavigationBinder({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<PushNavigationBinder> createState() => _PushNavigationBinderState();
}

class _PushNavigationBinderState extends State<PushNavigationBinder> {
  @override
  void initState() {
    super.initState();
    PushNotifications.attach(
      router: widget.router,
      onForegroundMessage: _onForegroundMessage,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotifications.handleLaunchNotification();
    });
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (!mounted) {
      return;
    }
    context.read<InboxRealtimeTick>().ping();
    final title = message.notification?.title;
    if (title == null || title.isEmpty) {
      return;
    }
    final body = message.notification?.body;
    showUserMessageSnackBar(
      context,
      body != null && body.isNotEmpty ? '$title — $body' : title,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
