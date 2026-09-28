/// Store copy and plan selection shared by the Premium screen.
///
/// iOS and Android use the same product IDs (`connectghin_monthly`,
/// `connectghin_yearly`). Those IDs are valid on both stores and are not
/// shown to users when a product query fails.
enum StoreBillingPlatform { appleAppStore, googlePlay }

/// Shown when the store returns no purchasable products. Diagnostics stay in logs.
const String kSubscriptionsUnavailableMessage =
    'Subscriptions are temporarily unavailable. Please try again later.';

/// The plan the user highlighted. Does not substitute the other plan.
T? selectedStoreProduct<T>({
  required bool yearlySelected,
  required T? monthly,
  required T? yearly,
}) {
  return yearlySelected ? yearly : monthly;
}

bool canStartStorePurchase<T>({
  required bool yearlySelected,
  required T? monthly,
  required T? yearly,
}) {
  return selectedStoreProduct<T>(
        yearlySelected: yearlySelected,
        monthly: monthly,
        yearly: yearly,
      ) !=
      null;
}

class StoreBillingCopy {
  const StoreBillingCopy(this.platform);

  final StoreBillingPlatform platform;

  bool get isApple => platform == StoreBillingPlatform.appleAppStore;

  String get renewalDisclosure => isApple
      ? 'Subscriptions are purchased and renewed through the Apple App Store. '
          'Manage or cancel anytime in your Apple ID account settings.'
      : 'Subscriptions are purchased and renewed through Google Play. '
          'Manage or cancel anytime in your Google Play account settings.';

  String get subscribeButtonLabel =>
      isApple ? 'Subscribe with App Store' : 'Subscribe with Google Play';

  String get cancelAnytimeSentence => isApple
      ? 'Cancel anytime in the Apple App Store.'
      : 'Cancel anytime in Google Play.';

  String get annualBillingNote => isApple
      ? 'Billed once per year through the Apple App Store'
      : 'Billed once per year through Google Play';

  String get cancelDialogBody => isApple
      ? 'This marks your Premium status as canceled in Connectghin. '
          'To stop recurring charges, cancel the subscription in the Apple App Store.'
      : 'This marks your Premium status as canceled in Connectghin. '
          'To stop recurring charges, cancel the subscription in Google Play.';

  String get manageSubscriptionSubtitle => isApple
      ? 'Open Apple ID subscription management'
      : 'Open Google Play subscription management';

  String get purchaseHistorySubtitle => isApple
      ? 'View purchases in your Apple ID account'
      : 'View purchases in your Google Play account';

  String get unmanagedSubscriptionHint => isApple
      ? 'Complete an in-app subscription to manage billing in your Apple ID account.'
      : 'Complete an in-app subscription to manage billing in your Google Play account.';

  String get storeManagementLaunchFailure => isApple
      ? 'Open the App Store to manage your subscription.'
      : 'Open Google Play to manage your subscription.';

  String get subscriptionManagementUrl => isApple
      ? 'https://apps.apple.com/account/subscriptions'
      : 'https://play.google.com/store/account/subscriptions';

  String get alreadyOwnedFollowUp => isApple
      ? 'The App Store shows an existing subscription. Tap Restore Purchases.'
      : 'Play shows an existing subscription. Tap Restore Purchases, or confirm Google Play API credentials on the server.';

  String restoreResult({
    required bool unlocked,
    required int syncedFromStore,
  }) {
    if (unlocked) return 'Premium restored successfully.';
    if (syncedFromStore > 0) {
      return 'A store purchase was found, but it could not be verified. Please try again later.';
    }
    return isApple
        ? 'No active subscription found for this Apple ID.'
        : 'No active subscription found on this Google account.';
  }
}
