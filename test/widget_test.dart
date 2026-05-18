import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:connectghin_flutter/app/router/app_router.dart';
import 'package:connectghin_flutter/app/session/auth_session.dart';
import 'package:connectghin_flutter/main.dart';

void main() {
  testWidgets('App boots with router', (WidgetTester tester) async {
    final session = AuthSession();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthSession>.value(
        value: session,
        child: ConnectGhinApp(router: createAppRouter(session)),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
