/// Google Play / App Store subscription product IDs (must match store consoles exactly).
abstract final class IapProductConfig {
  static const String monthlyProductId = String.fromEnvironment(
    'IAP_MONTHLY_PRODUCT_ID',
    defaultValue: 'connectghin.premium.monthly',
  );

  static const String yearlyProductId = String.fromEnvironment(
    'IAP_YEARLY_PRODUCT_ID',
    defaultValue: 'connectghin.premium.yearly',
  );

  static Set<String> get allIds => {monthlyProductId, yearlyProductId};
}
