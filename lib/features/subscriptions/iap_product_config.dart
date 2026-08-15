/// Google Play / App Store subscription product IDs (must match store consoles exactly).
abstract final class IapProductConfig {
  static const String androidPackageName = 'com.connectghin.app';
  static const String iosBundleId = 'com.connectghin.app';

  static const String monthlyProductId = String.fromEnvironment(
    'IAP_MONTHLY_PRODUCT_ID',
    defaultValue: 'connectghin_monthly',
  );

  static const String yearlyProductId = String.fromEnvironment(
    'IAP_YEARLY_PRODUCT_ID',
    defaultValue: 'connectghin_yearly',
  );

  static Set<String> get allIds => {monthlyProductId, yearlyProductId};
}
