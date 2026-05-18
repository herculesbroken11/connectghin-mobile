import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app/inbox_socket_binder.dart';
import 'app/router/app_router.dart';
import 'app/session/auth_session.dart';
import 'app/theme/app_theme.dart';
import 'features/messages/data/inbox_realtime_tick.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    return InboxSocketBinder(
      child: MaterialApp.router(
        title: 'ConnectGHIN',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }
}
