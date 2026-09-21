import 'package:connectghin_flutter/data/api_profile.dart';
import 'package:connectghin_flutter/features/ghinder/feed_post_create_ux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('afterSuccessfulFeedPostCreate', () {
    test('successful post shows success SnackBar message and reloads', () async {
      var createCount = 0;
      var closeCount = 0;
      String? shownMessage;
      var reloadCount = 0;

      await afterSuccessfulFeedPostCreate(
        create: () async {
          createCount += 1;
        },
        closeSheet: () {
          closeCount += 1;
        },
        showSuccess: (message) {
          shownMessage = message;
        },
        reloadFeed: () async {
          reloadCount += 1;
        },
      );

      expect(createCount, 1);
      expect(closeCount, 1);
      expect(shownMessage, kFoursomeFeedPostSuccessMessage);
      expect(
        shownMessage,
        'Your open spot was posted successfully.',
      );
      expect(reloadCount, 1);
    });

    test('failed post does not show success SnackBar or close/reload', () async {
      var closeCount = 0;
      String? shownMessage;
      var reloadCount = 0;

      await expectLater(
        () => afterSuccessfulFeedPostCreate(
          create: () async {
            throw Exception('create failed');
          },
          closeSheet: () {
            closeCount += 1;
          },
          showSuccess: (message) {
            shownMessage = message;
          },
          reloadFeed: () async {
            reloadCount += 1;
          },
        ),
        throwsA(isA<Exception>()),
      );

      expect(closeCount, 0);
      expect(shownMessage, isNull);
      expect(reloadCount, 0);
    });
  });

  group('FeedPostSubmitGate', () {
    test('blocks duplicate submit while request is in progress', () async {
      final gate = FeedPostSubmitGate();
      var runs = 0;

      final first = gate.run(() async {
        runs += 1;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(gate.isBusy, isTrue);

      await gate.run(() async {
        runs += 1;
      });
      expect(runs, 1);

      await first;
      expect(gate.isBusy, isFalse);

      await gate.run(() async {
        runs += 1;
      });
      expect(runs, 2);
    });
  });

  group('own Feed posts', () {
    test('successful post refresh keeps own post identifiable', () {
      final me = 'user-reviewer';
      final items = [
        {
          'id': 'post-own',
          'posterId': me,
          'userId': me,
          'courseName': 'Lions Municipal Golf Course',
          'city': 'Austin',
          'state': 'TX',
          'roundDate': '2026-09-22T00:00:00.000Z',
          'teeTime': '7:30 AM',
          'spotsNeeded': 2,
          'gameStyle': 'CASUAL',
          'status': 'OPEN',
          'createdAt': '2026-09-21T16:00:00.000Z',
          'poster': {'id': me, 'displayName': 'Google Reviewer', 'username': 'google_reviewer'},
        },
        {
          'id': 'post-other',
          'posterId': 'user-other',
          'userId': 'user-other',
          'courseName': 'Austin GC',
          'city': 'Austin',
          'state': 'TX',
          'roundDate': '2026-09-23T00:00:00.000Z',
          'teeTime': '9:00 AM',
          'spotsNeeded': 1,
          'gameStyle': 'CASUAL',
          'status': 'OPEN',
          'createdAt': '2026-09-21T15:00:00.000Z',
          'poster': {'id': 'user-other', 'displayName': 'Demo Golfer', 'username': 'demo_golfer'},
        },
      ];

      final posts = items
          .map((e) => FoursomeFeedPost.fromJson(e))
          .whereType<FoursomeFeedPost>()
          .toList();

      expect(posts.length, 2);
      final own = posts.firstWhere((p) => p.id == 'post-own');
      final other = posts.firstWhere((p) => p.id == 'post-other');

      expect(isOwnFeedPost(posterId: own.posterId, currentUserId: me), isTrue);
      expect(isOwnFeedPost(posterId: other.posterId, currentUserId: me), isFalse);

      expect(feedPostAllowsContact(isOwnPost: true), isFalse);
      expect(feedPostAllowsReport(isOwnPost: true), isFalse);
      expect(feedPostAllowsContact(isOwnPost: false), isTrue);
      expect(feedPostAllowsReport(isOwnPost: false), isTrue);
      expect(kFoursomeFeedOwnPostLabel, 'Your post');
    });

    test('own post does not show Contact or allow self-report', () {
      expect(feedPostAllowsContact(isOwnPost: true), isFalse);
      expect(feedPostAllowsReport(isOwnPost: true), isFalse);
    });

    test('another user post still allows Contact and report', () {
      expect(feedPostAllowsContact(isOwnPost: false), isTrue);
      expect(feedPostAllowsReport(isOwnPost: false), isTrue);
    });
  });
}
