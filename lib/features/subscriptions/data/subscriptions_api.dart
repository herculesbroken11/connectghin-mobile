import '../../../core/network/api_client.dart';

class SubscriptionsApi {
  SubscriptionsApi(this._apiClient);

  final ApiClient _apiClient;

  /// Backend-verified subscription status (never trust client-only premium flags).
  Future<Map<String, dynamic>> billingMe(String accessToken) {
    return _apiClient.getJson('/billing/me', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>?> me(String accessToken) {
    return _apiClient.getJsonObjectOrNull('/subscriptions/me', bearerToken: accessToken);
  }

  /// Syncs verified mobile store entitlement to backend membership state.
  Future<Map<String, dynamic>> syncEntitlement(
    String accessToken, {
    required String provider,
    required String productId,
    required String billingCycle,
    required String status,
    String? externalSubscriptionId,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
  }) {
    return _apiClient.postJson(
      '/subscriptions/entitlements/sync',
      bearerToken: accessToken,
      body: <String, dynamic>{
        'provider': provider,
        'productId': productId,
        'billingCycle': billingCycle,
        'status': status,
        if (externalSubscriptionId != null && externalSubscriptionId.isNotEmpty)
          'externalSubscriptionId': externalSubscriptionId,
        if (currentPeriodStart != null) 'currentPeriodStart': currentPeriodStart.toUtc().toIso8601String(),
        if (currentPeriodEnd != null) 'currentPeriodEnd': currentPeriodEnd.toUtc().toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>> verifyAppleEntitlement(
    String accessToken, {
    required String transactionId,
  }) {
    return _apiClient.postJson(
      '/subscriptions/entitlements/verify/apple',
      bearerToken: accessToken,
      body: <String, dynamic>{'transactionId': transactionId},
    );
  }

  /// Legacy Google verify endpoint (prefer [verifyGooglePlayPurchase]).
  Future<Map<String, dynamic>> verifyGoogleEntitlement(
    String accessToken, {
    required String purchaseToken,
  }) {
    return _apiClient.postJson(
      '/subscriptions/entitlements/verify/google',
      bearerToken: accessToken,
      body: <String, dynamic>{'purchaseToken': purchaseToken},
    );
  }

  /// Verifies a Google Play subscription with backend Google Play Developer API checks.
  Future<Map<String, dynamic>> verifyGooglePlayPurchase(
    String accessToken, {
    required String purchaseToken,
    required String productId,
    String? packageName,
  }) {
    return _apiClient.postJson(
      '/billing/google/verify',
      bearerToken: accessToken,
      body: <String, dynamic>{
        'purchaseToken': purchaseToken,
        'productId': productId,
        if (packageName != null && packageName.isNotEmpty) 'packageName': packageName,
      },
    );
  }

  /// Re-verifies the user's Google Play subscription with the backend.
  Future<Map<String, dynamic>> restoreGooglePlayPurchases(
    String accessToken, {
    String? purchaseToken,
    String? productId,
    String? packageName,
  }) {
    return _apiClient.postJson(
      '/billing/google/restore',
      bearerToken: accessToken,
      body: <String, dynamic>{
        if (purchaseToken != null && purchaseToken.isNotEmpty) 'purchaseToken': purchaseToken,
        if (productId != null && productId.isNotEmpty) 'productId': productId,
        if (packageName != null && packageName.isNotEmpty) 'packageName': packageName,
      },
    );
  }

  Future<Map<String, dynamic>> cancel(String accessToken) {
    return _apiClient.postJson('/subscriptions/cancel', bearerToken: accessToken);
  }
}
