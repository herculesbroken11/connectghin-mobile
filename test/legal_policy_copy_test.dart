import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connectghin_flutter/features/misc/misc_screens.dart';
import 'package:connectghin_flutter/features/settings/privacy_policy_screen.dart';

void main() {
  const termsTitles = [
    '1. Acceptance of Terms',
    '2. Eligibility',
    '3. Description of Service',
    '4. User Accounts',
    '5. User-Generated Content and Content Rights',
    '6. Community Conduct and Safety',
    '7. Reporting, Blocking and Moderation',
    '8. Subscriptions and Billing',
    '9. Third-Party Services',
    '10. Account Deletion',
    '11. Intellectual Property',
    '12. Disclaimers and Limitation of Liability',
    '13. Changes',
    '14. Contact',
  ];

  const privacyTitles = [
    '1. Introduction',
    '2. Information Collected',
    '3. How Information Is Used',
    '4. Information Visible to Other Users',
    '5. Service Providers and Disclosure',
    '6. Tracking and Cookies',
    '7. Data Retention',
    '8. Account Deletion',
    '9. Your Privacy Rights',
    '10. Data Security',
    '11. Children and Age',
    '12. Policy Changes',
    '13. Contact',
  ];

  Future<void> pumpLegal(WidgetTester tester, Widget screen, Size logicalSize) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = logicalSize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Future<String> scrolledText(WidgetTester tester) async {
    final seen = <String>{};
    void collect() {
      for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
        seen.add(widget.text.toPlainText());
      }
    }

    collect();
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pump();
      collect();
    }
    return seen.join('\n');
  }

  testWidgets('Terms matches the September 30, 2026 website sections', (tester) async {
    await pumpLegal(tester, const TermsOfServiceScreen(), const Size(390, 844));
    final text = await scrolledText(tester);
    expect(text, contains('Last updated: September 30, 2026'));
    for (final title in termsTitles) {
      expect(text, contains(title));
    }
    expect(text, contains('https://connectghin.com/privacy'));
    expect(text, contains('https://connectghin.com/child-safety'));
    expect(text, contains('https://connectghin.com/delete-account'));
    expect(text, contains('support@connectghin.com'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Privacy matches the September 30, 2026 website sections', (tester) async {
    await pumpLegal(tester, const PrivacyPolicyScreen(), const Size(390, 844));
    final text = await scrolledText(tester);
    expect(text, contains('Last updated: September 30, 2026'));
    for (final title in privacyTitles) {
      expect(text, contains(title));
    }
    expect(text, contains('https://connectghin.com/terms'));
    expect(text, contains('https://connectghin.com/child-safety'));
    expect(text, contains('https://connectghin.com/delete-account'));
    expect(text, contains('privacy@connectghin.com'));
    expect(text, contains('support@connectghin.com'));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(390, 844)]) {
    testWidgets('Terms scrolls without overflow at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpLegal(tester, const TermsOfServiceScreen(), size);
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('14. Contact'), 300, scrollable: list);
      expect(find.text('14. Contact'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Privacy scrolls without overflow at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpLegal(tester, const PrivacyPolicyScreen(), size);
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('13. Contact'), 300, scrollable: list);
      expect(find.text('13. Contact'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
