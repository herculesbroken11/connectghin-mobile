import 'package:connectghin_flutter/features/ghinder/ghinder_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feed mode constants', () {
    test('Pair Up is default mode index 0', () {
      expect(kFeedModePairUp, 0);
      expect(kFeedModeFoursome, 1);
    });

    test('mode labels match product copy', () {
      expect(kFeedModePairUpLabel, 'Pair Up');
      expect(kFeedModeFoursomeLabel, 'Foursome Feed');
    });

    test('labels are distinct and non-empty', () {
      expect(kFeedModePairUpLabel, isNotEmpty);
      expect(kFeedModeFoursomeLabel, isNotEmpty);
      expect(kFeedModePairUpLabel, isNot(equals(kFeedModeFoursomeLabel)));
    });
  });
}
