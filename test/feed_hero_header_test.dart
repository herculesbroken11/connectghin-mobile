import 'package:connectghin_flutter/features/ghinder/ghinder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHero(
    WidgetTester tester, {
    required Size logical,
    required double topInset,
    required double textScale,
  }) async {
    tester.view.physicalSize = Size(logical.width * 3, logical.height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(top: topInset),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: Scaffold(
          body: Column(
            children: [
              FeedHeroHeader(isPremium: false, onPremium: () {}),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('Feed hero clears an iPhone 17 Pro safe area without overflow', (tester) async {
    const logical = Size(402, 874);
    const topInset = 62.0;
    await pumpHero(tester, logical: logical, topInset: topInset, textScale: 1);
    expect(tester.takeException(), isNull);

    final header = tester.getSize(find.byType(FeedHeroHeader));
    expect(header.height, greaterThan(150));
    expect(tester.getRect(find.text('Premium')).top, greaterThanOrEqualTo(topInset));
    expect(tester.getRect(find.text('The Feed')).top, greaterThan(topInset));
    expect(find.text('Find golfers looking for open spots nearby'), findsOneWidget);
    final subtitle = tester.getRect(find.text('Find golfers looking for open spots nearby'));
    expect(subtitle.bottom, lessThan(header.height + 1));
    expect(subtitle.right, lessThanOrEqualTo(logical.width));
  });

  testWidgets('Feed hero grows with text scale on a smaller phone', (tester) async {
    const logical = Size(375, 667);
    await pumpHero(tester, logical: logical, topInset: 20, textScale: 1);
    expect(tester.takeException(), isNull);
    final normal = tester.getSize(find.byType(FeedHeroHeader)).height;

    await pumpHero(tester, logical: logical, topInset: 47, textScale: 1.6);
    expect(tester.takeException(), isNull);
    expect(find.text('The Feed'), findsOneWidget);
    expect(find.text('Find golfers looking for open spots nearby'), findsOneWidget);
    expect(tester.getRect(find.text('The Feed')).top, greaterThan(47));
    expect(tester.getSize(find.byType(FeedHeroHeader)).height, greaterThan(normal));
  });
}
