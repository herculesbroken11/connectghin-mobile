import 'dart:io';

import 'package:connectghin_flutter/features/subscriptions/store_billing_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apple = StoreBillingCopy(StoreBillingPlatform.appleAppStore);
  const google = StoreBillingCopy(StoreBillingPlatform.googlePlay);

  String visible(StoreBillingCopy copy) => [
        copy.renewalDisclosure,
        copy.subscribeButtonLabel,
        copy.cancelAnytimeSentence,
        copy.annualBillingNote,
        copy.cancelDialogBody,
        copy.manageSubscriptionSubtitle,
        copy.purchaseHistorySubtitle,
        copy.unmanagedSubscriptionHint,
        copy.storeManagementLaunchFailure,
        copy.alreadyOwnedFollowUp,
        copy.restoreResult(unlocked: false, syncedFromStore: 0),
        copy.restoreResult(unlocked: false, syncedFromStore: 1),
        copy.restoreResult(unlocked: true, syncedFromStore: 0),
        kSubscriptionsUnavailableMessage,
      ].join('\n');

  test('iOS Premium copy does not mention Google Play or Apple Pay', () {
    final blob = visible(apple).toLowerCase();
    expect(blob.contains('google play'), isFalse);
    expect(blob.contains('google account'), isFalse);
    expect(blob.contains('apple pay'), isFalse);
    expect(blob.contains('app store / google play'), isFalse);
    expect(apple.renewalDisclosure, contains('Apple App Store'));
    expect(apple.renewalDisclosure, contains('Apple ID'));
    expect(apple.subscribeButtonLabel, 'Subscribe with App Store');
  });

  test('Android Premium copy does not mention the Apple App Store', () {
    final blob = visible(google).toLowerCase();
    expect(blob.contains('apple'), isFalse);
    expect(blob.contains('app store'), isFalse);
    expect(blob.contains('google play'), isTrue);
    expect(google.subscribeButtonLabel, 'Subscribe with Google Play');
    expect(google.cancelAnytimeSentence, 'Cancel anytime in Google Play.');
  });

  test('user-facing store failure does not include product IDs', () {
    expect(kSubscriptionsUnavailableMessage, contains('temporarily unavailable'));
    expect(kSubscriptionsUnavailableMessage.contains('connectghin_'), isFalse);
    expect(kSubscriptionsUnavailableMessage.toLowerCase(), isNot(contains('play console')));
    final screen = File('lib/features/membership/membership_screens.dart').readAsStringSync();
    expect(screen.contains('Products not found in store'), isFalse);
    expect(screen.contains('App Store / Google Play'), isFalse);
    expect(screen.contains('Apple App Store or Google Play'), isFalse);
    expect(screen.contains('kSubscriptionsUnavailableMessage'), isTrue);
  });

  test('product selection uses only the highlighted plan', () {
    expect(
      selectedStoreProduct(yearlySelected: true, monthly: 'monthly', yearly: 'yearly'),
      'yearly',
    );
    expect(
      selectedStoreProduct(yearlySelected: false, monthly: 'monthly', yearly: 'yearly'),
      'monthly',
    );
    expect(
      selectedStoreProduct<String>(yearlySelected: true, monthly: 'monthly', yearly: null),
      isNull,
    );
    expect(
      canStartStorePurchase(yearlySelected: false, monthly: 'monthly', yearly: null),
      isTrue,
    );
    expect(
      canStartStorePurchase<String>(yearlySelected: true, monthly: 'monthly', yearly: null),
      isFalse,
    );
    expect(
      canStartStorePurchase<String>(yearlySelected: false, monthly: null, yearly: null),
      isFalse,
    );
  });

  test('restore result stays user-safe for each store', () {
    expect(
      apple.restoreResult(unlocked: true, syncedFromStore: 0),
      'Premium restored successfully.',
    );
    expect(
      google.restoreResult(unlocked: true, syncedFromStore: 2),
      'Premium restored successfully.',
    );
    expect(
      apple.restoreResult(unlocked: false, syncedFromStore: 0),
      'No active subscription found for this Apple ID.',
    );
    expect(
      google.restoreResult(unlocked: false, syncedFromStore: 0),
      'No active subscription found on this Google account.',
    );
    final unverified = apple.restoreResult(unlocked: false, syncedFromStore: 1);
    expect(unverified, contains('could not be verified'));
    expect(unverified.contains('connectghin_'), isFalse);
  });
}
