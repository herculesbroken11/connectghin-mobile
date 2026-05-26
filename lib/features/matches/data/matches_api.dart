import '../../../core/network/api_client.dart';

class MatchesApi {
  MatchesApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> list(String accessToken) {
    return _apiClient.getJsonList('/matches', bearerToken: accessToken);
  }

  Future<void> unmatch({
    required String accessToken,
    required String matchId,
  }) {
    return _apiClient.deleteJson('/matches/$matchId', bearerToken: accessToken);
  }
}
