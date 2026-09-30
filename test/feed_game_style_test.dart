import 'package:connectghin_flutter/data/api_profile.dart';
import 'package:connectghin_flutter/features/ghinder/feed_game_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _postJson(String id, String gameStyle) {
  return <String, dynamic>{
    'id': id,
    'posterId': 'user-1',
    'courseName': 'Harding Park',
    'city': 'San Francisco',
    'state': 'CA',
    'roundDate': '2026-10-02T00:00:00.000Z',
    'teeTime': '7:30 AM',
    'spotsNeeded': 1,
    'gameStyle': gameStyle,
    'notes': 'Serious pace',
    'status': 'OPEN',
    'createdAt': '2026-09-30T16:00:00.000Z',
    'poster': {'id': 'user-1', 'displayName': 'Alex', 'username': 'alex'},
  };
}

FoursomeFeedPost _post(String id, String gameStyle) {
  return FoursomeFeedPost.fromJson(_postJson(id, gameStyle))!;
}

void main() {
  test('create request sends the selected game style enum', () {
    final casual = foursomeFeedCreateBody(
      courseName: 'Harding Park',
      roundDateIso: '2026-10-02T00:00:00.000',
      teeTime: '7:30 AM',
      spotsNeeded: 1,
      gameStyle: 'CASUAL',
    );
    final serious = foursomeFeedCreateBody(
      courseName: 'Harding Park',
      roundDateIso: '2026-10-02T00:00:00.000',
      teeTime: '7:30 AM',
      spotsNeeded: 1,
      gameStyle: 'SERIOUS',
      notes: 'Serious pace',
    );
    final tournament = foursomeFeedCreateBody(
      courseName: 'Harding Park',
      roundDateIso: '2026-10-02T00:00:00.000',
      teeTime: '7:30 AM',
      spotsNeeded: 1,
      gameStyle: 'TOURNAMENT',
    );

    expect(casual['gameStyle'], 'CASUAL');
    expect(serious['gameStyle'], 'SERIOUS');
    expect(tournament['gameStyle'], 'TOURNAMENT');
    expect(serious['notes'], 'Serious pace');
  });

  test('Serious and Tournament are not rewritten to Casual', () {
    expect(canonicalFeedGameStyle('serious'), 'SERIOUS');
    expect(canonicalFeedGameStyle('Tournament'), 'TOURNAMENT');
    expect(canonicalFeedGameStyle(null), isNull);
    expect(canonicalFeedGameStyle(''), isNull);
    expect(
      () => foursomeFeedCreateBody(
        courseName: 'Harding Park',
        roundDateIso: '2026-10-02T00:00:00.000',
        teeTime: '7:30 AM',
        spotsNeeded: 1,
        gameStyle: 'FUN',
      ),
      throwsArgumentError,
    );
  });

  test('each tab keeps only its own posts', () {
    final posts = [
      _post('c', 'CASUAL'),
      _post('s', 'SERIOUS'),
      _post('t', 'TOURNAMENT'),
    ];

    expect(
      postsForFeedStyle(posts, 'CASUAL', (p) => p.gameStyle).map((p) => p.id),
      ['c'],
    );
    expect(
      postsForFeedStyle(posts, 'SERIOUS', (p) => p.gameStyle).map((p) => p.id),
      ['s'],
    );
    expect(
      postsForFeedStyle(posts, 'TOURNAMENT', (p) => p.gameStyle).map((p) => p.id),
      ['t'],
    );
    expect(
      postsForFeedStyle(posts, 'CASUAL', (p) => p.gameStyle).map((p) => p.gameStyle),
      isNot(contains('SERIOUS')),
    );
    expect(
      postsForFeedStyle(posts, 'CASUAL', (p) => p.gameStyle).map((p) => p.gameStyle),
      isNot(contains('TOURNAMENT')),
    );
    expect(
      postsForFeedStyle(posts, 'SERIOUS', (p) => p.gameStyle).map((p) => p.gameStyle),
      isNot(contains('TOURNAMENT')),
    );
  });

  test('game style survives a re-fetch of the same payload', () {
    final first = _post('s', 'SERIOUS');
    final again = FoursomeFeedPost.fromJson(_postJson('s', first.gameStyle))!;
    expect(again.gameStyle, 'SERIOUS');
    expect(again.gameStyleLabel, 'Serious');
    expect(
      postsForFeedStyle([again], 'CASUAL', (p) => p.gameStyle),
      isEmpty,
    );
  });

  test('a missing game style is not treated as Casual', () {
    final json = _postJson('x', 'SERIOUS')..remove('gameStyle');
    final post = FoursomeFeedPost.fromJson(json)!;
    expect(post.gameStyle, isEmpty);
    expect(post.gameStyleLabel, isNot('Casual'));
    expect(postsForFeedStyle([post], 'CASUAL', (p) => p.gameStyle), isEmpty);
  });

  test('legacy COMPETITIVE posts stay out of Casual, Serious, and Tournament', () {
    final legacy = _post('legacy', 'COMPETITIVE');
    final serious = _post('s', 'SERIOUS');

    expect(canonicalFeedGameStyle('COMPETITIVE'), isNull);
    expect(legacy.gameStyle, 'COMPETITIVE');
    expect(legacy.gameStyleLabel, 'Competitive');

    for (final tab in ['CASUAL', 'SERIOUS', 'TOURNAMENT']) {
      expect(
        postsForFeedStyle([legacy, serious], tab, (p) => p.gameStyle).map((p) => p.gameStyle),
        isNot(contains('COMPETITIVE')),
      );
    }
    expect(
      postsForFeedStyle([legacy, serious], 'SERIOUS', (p) => p.gameStyle).map((p) => p.id),
      ['s'],
    );
    expect(
      foursomeFeedCreateBody(
        courseName: 'Harding Park',
        roundDateIso: '2026-10-02T00:00:00.000',
        teeTime: '7:30 AM',
        spotsNeeded: 1,
        gameStyle: 'SERIOUS',
      )['gameStyle'],
      'SERIOUS',
    );
  });

  test('a Serious create refreshes the Serious tab, not Casual', () async {
    String? selected;
    var reloads = 0;
    await refreshFeedForCreatedStyle(
      gameStyle: 'SERIOUS',
      selectStyle: (style) => selected = style,
      reload: () async {
        reloads += 1;
        expect(selected, 'SERIOUS');
      },
    );
    expect(selected, 'SERIOUS');
    expect(reloads, 1);
  });

  testWidgets('selecting Serious is the value sent in the create body', (tester) async {
    String selected = 'CASUAL';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return FeedGameStyleChips(
                selected: selected,
                onSelected: (value) => setState(() => selected = value),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Serious'));
    await tester.pump();
    final body = foursomeFeedCreateBody(
      courseName: 'Harding Park',
      roundDateIso: '2026-10-02T00:00:00.000',
      teeTime: '7:30 AM',
      spotsNeeded: 1,
      gameStyle: selected,
    );
    expect(body['gameStyle'], 'SERIOUS');

    await tester.tap(find.text('Tournament'));
    await tester.pump();
    expect(
      foursomeFeedCreateBody(
        courseName: 'Harding Park',
        roundDateIso: '2026-10-02T00:00:00.000',
        teeTime: '7:30 AM',
        spotsNeeded: 1,
        gameStyle: selected,
      )['gameStyle'],
      'TOURNAMENT',
    );

    await tester.tap(find.text('Casual'));
    await tester.pump();
    expect(
      foursomeFeedCreateBody(
        courseName: 'Harding Park',
        roundDateIso: '2026-10-02T00:00:00.000',
        teeTime: '7:30 AM',
        spotsNeeded: 1,
        gameStyle: selected,
      )['gameStyle'],
      'CASUAL',
    );
  });
}
