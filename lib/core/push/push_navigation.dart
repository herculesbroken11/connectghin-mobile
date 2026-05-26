import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_paths.dart';

/// Deep-links from FCM `data` payloads (see backend `flattenDataJsonForFcm`).
abstract final class PushNavigation {
  static void navigateFromMessage(GoRouter router, RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) {
      router.go(AppPaths.appNotifications);
      return;
    }

    final type = data['type'];
    final conversationId = data['conversationId'];
    if (conversationId != null && conversationId.isNotEmpty) {
      router.go(AppPaths.appMessageThread(conversationId));
      return;
    }

    final matchedUserId = data['matchedUserId'];
    if (type == 'NEW_MATCH' ||
        (matchedUserId != null && matchedUserId.isNotEmpty)) {
      router.go(AppPaths.appMatches);
      return;
    }

    router.go(AppPaths.appNotifications);
  }
}
