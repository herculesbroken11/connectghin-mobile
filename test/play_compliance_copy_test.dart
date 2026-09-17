import 'dart:io';

import 'package:connectghin_flutter/features/ghinder/report_feed_post_sheet.dart';
import 'package:connectghin_flutter/features/membership/premium_benefits.dart';
import 'package:connectghin_flutter/features/shell/app_bottom_nav_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bottom nav uses Connect and The Feed labels', () {
    expect(AppBottomNavBar.labels, contains('Connect'));
    expect(AppBottomNavBar.labels, contains('The Feed'));
    expect(AppBottomNavBar.labels, isNot(contains('Discover')));
    expect(AppBottomNavBar.labels, isNot(contains('Pair Up')));
    expect(AppBottomNavBar.labels, isNot(contains('Find Your 4th')));
  });

  test('Feed report reasons include required Play safety categories', () {
    final codes = kFeedReportReasons.map((e) => e.$1).toSet();
    expect(codes.contains('HARASSMENT'), isTrue);
    expect(codes.contains('HATE'), isTrue);
    expect(codes.contains('SEXUAL'), isTrue);
    expect(codes.contains('SPAM'), isTrue);
    expect(codes.contains('DANGEROUS'), isTrue);
    expect(codes.contains('OTHER'), isTrue);
    expect(kFeedReportReasons.any((e) => e.$2.contains('Report') == false), isTrue);
  });

  test('Premium benefits list matches implemented entitlements only', () {
    final blob = PremiumBenefits.items.map((e) => '${e.$1} ${e.$2}').join(' ').toLowerCase();
    expect(blob.contains('see who likes'), isFalse);
    expect(blob.contains('profile boost'), isFalse);
    expect(blob.contains('message anyone'), isFalse);
    expect(blob.contains('priority'), isFalse);
    expect(blob.contains('unlimited connect'), isTrue);
    expect(blob.contains('feed'), isTrue);
    expect(blob.contains('post open spots'), isTrue);
    expect(blob.contains('contact'), isTrue);
    expect(blob.contains('premium badge'), isTrue);
    expect(PremiumBenefits.items.length, 5);
  });

  test('Production lib strings avoid obsolete nav labels and unsafe claims', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    const obsoleteNavLabels = ['Pair Up', 'Find Your 4th'];
    const unsafeVisiblePhrases = [
      'See who likes you',
      'Profile Boost',
      'Message anyone',
      'priority placement',
      'Official GHIN',
      'GHIN Verified',
      'USGA Verified',
      'Official Handicap Verification',
      'official handicap',
      'Your Premier Golf Network',
      'the premier golf network',
      'premier golf',
    ];

    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.replaceAll('\\', '/');
      if (relative.contains('/data/') || relative.contains('/api/')) continue;

      final content = entity
          .readAsStringSync()
          .split('\n')
          .where((line) {
            final trimmed = line.trim();
            return !trimmed.startsWith('//') && !trimmed.startsWith('///');
          })
          .join('\n');
      for (final label in obsoleteNavLabels) {
        if (content.contains("'$label'") || content.contains('"$label"')) {
          violations.add('$relative contains obsolete nav label: $label');
        }
      }
      for (final phrase in unsafeVisiblePhrases) {
        if (content.contains("'$phrase") ||
            content.contains('"$phrase') ||
            content.contains("'$phrase'") ||
            content.contains('"$phrase"')) {
          violations.add('$relative contains unsafe visible phrase: $phrase');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('Delete account copy mentions store billing separately', () {
    final file = File('lib/features/settings/delete_account_flow_screen.dart');
    final content = file.readAsStringSync().toLowerCase();
    expect(content.contains('google play'), isTrue);
    expect(content.contains('app store'), isTrue);
    expect(content.contains('30 day'), isFalse);
    expect(content.contains('anonymiz'), isTrue);
  });
}
