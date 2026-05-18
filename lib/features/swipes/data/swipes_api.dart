import '../../../core/network/api_client.dart';
import '../swipe_daily_quota.dart';

class SwipesApi {
  SwipesApi(this._apiClient);

  final ApiClient _apiClient;

  Future<SwipeDailyQuota> fetchDailyQuota(String accessToken) async {
    final m = await _apiClient.getJson('/swipes/daily-status', bearerToken: accessToken);
    return SwipeDailyQuota.fromJson(m);
  }

  /// [action] `LIKE` or `PASS` (backend `SwipeAction`).
  Future<Map<String, dynamic>> swipe({
    required String accessToken,
    required String toUserId,
    required String action,
  }) {
    return _apiClient.postJson(
      '/swipes',
      bearerToken: accessToken,
      body: <String, dynamic>{
        'toUserId': toUserId,
        'action': action,
      },
    );
  }
}
