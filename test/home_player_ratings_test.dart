import 'package:connectghin_flutter/data/api_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home player ratings summary parsing', () {
    test('empty summary shows no ratings', () {
      final s = GolferRatingSummary.fromJson(null);
      expect(s.hasRating, isFalse);
      expect(s.reviewCount, 0);
    });

    test('approved profileSummary maps average and count', () {
      final s = GolferRatingSummary.fromJson({
        'averageRating': 4.8,
        'totalRatings': 12,
      });
      expect(s.hasRating, isTrue);
      expect(s.averageRating, 4.8);
      expect(s.reviewCount, 12);
    });
  });
}
