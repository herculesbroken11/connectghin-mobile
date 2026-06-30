import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/push/in_app_push_banner.dart';
import '../core/push/push_notifications.dart';
import '../core/push/push_navigation.dart';
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

    final conversationId = message.data['conversationId'];
    if (conversationId != null && conversationId.isNotEmpty) {
      final loc = widget.router.state.matchedLocation;
      if (loc.contains('/app/messages/$conversationId')) {
        return;
      }
    }

    InAppPushBanner.show(
      context,
      message: message,
      onTap: () => PushNavigation.navigateFromMessage(widget.router, message),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
