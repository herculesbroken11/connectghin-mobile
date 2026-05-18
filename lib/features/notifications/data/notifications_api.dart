import '../../../core/network/api_client.dart';

class NotificationsApi {
  NotificationsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> listNotifications(String accessToken) {
    return _apiClient.getJsonList('/notifications', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>> markRead({
    required String accessToken,
    required String notificationId,
  }) {
    return _apiClient.patchJson(
      '/notifications/$notificationId/read',
      bearerToken: accessToken,
      body: <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> markAllRead(String accessToken) {
    return _apiClient.patchJson(
      '/notifications/read-all',
      bearerToken: accessToken,
      body: <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> registerToken({
    required String accessToken,
    required String platform,
    required String token,
  }) {
    return _apiClient.postJson(
      '/devices/register-token',
      bearerToken: accessToken,
      body: <String, dynamic>{'platform': platform, 'token': token},
    );
  }
}
