import '../../../core/network/api_client.dart';

class PlayerRatingsApi {
  PlayerRatingsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> create({
    required String accessToken,
    required String revieweeUserId,
    required String roundDateIso,
    required String course,
    required int overallRating,
    required int handicapAccuracy,
    required int sportsmanship,
    required int paceOfPlay,
    required bool wouldPlayAgain,
    required String comment,
  }) {
    return _apiClient.postJson(
      '/player-ratings',
      bearerToken: accessToken,
      body: <String, dynamic>{
        'revieweeUserId': revieweeUserId,
        'roundDate': roundDateIso,
        'course': course,
        'overallRating': overallRating,
        'handicapAccuracy': handicapAccuracy,
        'sportsmanship': sportsmanship,
        'paceOfPlay': paceOfPlay,
        'wouldPlayAgain': wouldPlayAgain,
        'comment': comment,
      },
    );
  }

  Future<Map<String, dynamic>> listForUser(
    String accessToken,
    String userId, {
    String status = 'all',
    int page = 0,
    int pageSize = 20,
  }) {
    return _apiClient.getJson(
      '/player-ratings/users/$userId',
      bearerToken: accessToken,
      query: <String, String>{
        'status': status,
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
  }

  Future<Map<String, dynamic>> listMineGiven(
    String accessToken, {
    int page = 0,
    int pageSize = 20,
  }) {
    return _apiClient.getJson(
      '/player-ratings/me/given',
      bearerToken: accessToken,
      query: <String, String>{
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
  }

  Future<Map<String, dynamic>> detail(String accessToken, String ratingId) {
    return _apiClient.getJson('/player-ratings/$ratingId', bearerToken: accessToken);
  }
}
