import 'package:connectghin_flutter/core/network/api_user_message.dart';
import 'package:connectghin_flutter/core/premium/effective_premium.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isEffectivePremiumFromJson', () {
    test('prefers isPremium true from admin override / backend', () {
      expect(
        isEffectivePremiumFromJson({
          'isPremium': true,
          'membershipType': 'FREE',
          'membershipStatus': 'NONE',
        }),
        isTrue,
      );
    });

    test('hides upgrade path when isPremium is true regardless of membershipType', () {
      final premium = isEffectivePremiumFromJson({
        'isPremium': true,
        'membershipType': 'FREE',
      });
      expect(premium, isTrue);
    });

    test('returns false for free non-override users', () {
      expect(
        isEffectivePremiumFromJson({
          'isPremium': false,
          'membershipType': 'FREE',
          'membershipStatus': 'NONE',
        }),
        isFalse,
      );
    });
  });

  group('FCM user-facing errors', () {
    test('maps FIS_AUTH_ERROR to a safe notification message', () {
      final msg = messageFromApiError(
        Exception(
          '[firebase_messaging/unknown] java.io.IOException: '
          'java.util.concurrent.ExecutionException: java.io.IOException: FIS_AUTH_ERROR',
        ),
      );
      expect(msg, 'Notifications could not be enabled right now. Please try again later.');
      expect(msg.toLowerCase(), isNot(contains('fis_auth')));
      expect(msg.toLowerCase(), isNot(contains('java.io')));
    });

    test('does not leak PlatformException firebase details', () {
      final msg = messageFromApiError(
        Exception('PlatformException(firebase_messaging, unknown, null, null)'),
      );
      expect(msg.toLowerCase(), isNot(contains('platformexception')));
    });
  });
}
