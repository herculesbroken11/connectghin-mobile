import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:connectghin_flutter/app/router/app_router.dart';
import 'package:connectghin_flutter/app/session/auth_session.dart';

void main() {
  testWidgets('Router shell renders MaterialApp', (WidgetTester tester) async {
    final session = AuthSession();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthSession>.value(
        value: session,
        child: MaterialApp.router(
          routerConfig: createAppRouter(session),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
