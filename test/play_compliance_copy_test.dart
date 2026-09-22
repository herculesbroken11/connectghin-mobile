import 'dart:io';

import 'package:connectghin_flutter/features/ghinder/report_feed_post_sheet.dart';
import 'package:connectghin_flutter/features/membership/membership_screens.dart';
import 'package:connectghin_flutter/features/membership/premium_benefits.dart';
import 'package:connectghin_flutter/features/shell/app_bottom_nav_bar.dart';
import 'package:connectghin_flutter/features/subscriptions/iap_product_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bottom nav uses Connect and The Feed labels', () {
    expect(AppBottomNavBar.labels, contains('Connect'));
    expect(AppBottomNavBar.labels, contains('The Feed'));
    expect(AppBottomNavBar.labels, isNot(contains('Discover')));
    expect(AppBottomNavBar.labels, isNot(contains('Pair Up')));
    expect(AppBottomNavBar.labels, isNot(contains('Find Your 4th')));
  });

  test('The Feed screen has no Pair Up / Foursome Feed mode selector', () {
    final feed = File('lib/features/ghinder/ghinder_screen.dart').readAsStringSync();
    expect(feed.contains("kFeedModePairUpLabel"), isFalse);
    expect(feed.contains("'Pair Up'"), isFalse);
    expect(feed.contains('"Pair Up"'), isFalse);
    expect(feed.contains('Foursome Feed'), isFalse);
    expect(feed.contains('Open Connect'), isFalse);
    expect(feed.contains('IndexedStack'), isFalse);
    expect(feed.contains('The Feed'), isTrue);
    expect(feed.contains('Find golfers looking for open spots nearby'), isTrue);
  });

  test('Feed empty state does not push users to Connect', () {
    final tab = File('lib/features/ghinder/foursome_feed_tab.dart').readAsStringSync();
    expect(tab.contains('Open Connect'), isFalse);
    expect(tab.contains('Check back soon or post your own round.'), isTrue);
  });

  test('Home uses Player Ratings instead of Quick Actions', () {
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();
    expect(home.contains('Quick Actions'), isFalse);
    expect(home.contains('Your Player Ratings'), isTrue);
    expect(home.contains('No player ratings yet.'), isTrue);
  });

  test('IAP product IDs and Steve fallback prices', () {
    expect(IapProductConfig.monthlyProductId, 'connectghin_monthly');
    expect(IapProductConfig.yearlyProductId, 'connectghin_yearly');
    expect(kPremiumMonthlyDisplay, r'$2.99');
    expect(kPremiumYearlyDisplay, r'$29.99');
  });

  test('Feed report reasons include required Play safety categories', () {
    final codes = kFeedReportReasons.map((e) => e.$1).toSet();
    expect(codes.contains('HARASSMENT'), isTrue);
    expect(codes.contains('HATE'), isTrue);
    expect(codes.contains('SEXUAL'), isTrue);
    expect(codes.contains('SPAM'), isTrue);
    expect(codes.contains('DANGEROUS'), isTrue);
    expect(codes.contains('OTHER'), isTrue);
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
    expect(
      PremiumBenefits.compareFreeLines.any((e) => e.contains('Pair Up')),
      isFalse,
    );
  });

  test('Production lib strings avoid obsolete nav labels and unsafe claims', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    const obsoleteNavLabels = ['Find Your 4th'];
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
      'Open Connect',
      'Quick Actions',
      'Foursome Feed',
    ];

    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.replaceAll('\\', '/');
      if (relative.contains('/data/') || relative.contains('/api/')) continue;
      // Internal route/name DiscoverScreen is allowed; ban user-facing quoted Discover.
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
          // Allow Discover only in non-user path identifiers if needed — ban quoted UI labels.
          violations.add('$relative contains obsolete label: $label');
        }
      }
      for (final phrase in unsafeVisiblePhrases) {
        if (content.contains("'$phrase'") || content.contains('"$phrase"')) {
          violations.add('$relative contains unsafe/obsolete visible phrase: $phrase');
        }
      }
      // Pair Up must not remain as user-facing Feed mode label.
      if (content.contains("'Pair Up'") || content.contains('"Pair Up"')) {
        violations.add('$relative contains Pair Up user-facing string');
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
