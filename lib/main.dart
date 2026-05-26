import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app/config/env_config.dart';
import 'app/inbox_socket_binder.dart';
import 'app/push_navigation_binder.dart';
import 'app/push_token_binder.dart';
import 'app/router/app_router.dart';
import 'app/session/auth_session.dart';
import 'app/theme/app_theme.dart';
import 'core/push/push_notifications.dart';
import 'features/messages/data/inbox_realtime_tick.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  if (PushNotifications.isSupported) {
    await PushNotifications.init();
  }
  final session = AuthSession();
  await session.load();
  final router = createAppRouter(session);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthSession>.value(value: session),
        ChangeNotifierProvider<InboxRealtimeTick>(create: (_) => InboxRealtimeTick()),
      ],
      child: ConnectGhinApp(router: router),
    ),
  );
}

class ConnectGhinApp extends StatelessWidget {
  const ConnectGhinApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return PushNavigationBinder(
      router: router,
      child: InboxSocketBinder(
        child: PushTokenBinder(
          child: MaterialApp.router(
            title: 'ConnectGHIN',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      ),
    );
  }
}
