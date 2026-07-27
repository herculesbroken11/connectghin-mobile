import '../../../core/network/api_client.dart';

class SettingsApi {
  SettingsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>?> getMe(String accessToken) {
    return _apiClient.getJsonObjectOrNull('/settings/me', bearerToken: accessToken);
  }

  /// Dynamic Settings payload: profile + notification + privacy toggles.
  Future<Map<String, dynamic>> getOverview(String accessToken) {
    return _apiClient.getJson('/settings/overview', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>> patchMe({
    required String accessToken,
    required Map<String, bool> body,
  }) {
    return _apiClient.patchJson(
      '/settings/me',
      bearerToken: accessToken,
      body: body,
    );
  }
}
