import '../../../core/network/api_client.dart';

class SubscriptionsApi {
  SubscriptionsApi(this._apiClient);

  final ApiClient _apiClient;

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

  Future<Map<String, dynamic>> cancel(String accessToken) {
    return _apiClient.postJson('/subscriptions/cancel', bearerToken: accessToken);
  }
}
