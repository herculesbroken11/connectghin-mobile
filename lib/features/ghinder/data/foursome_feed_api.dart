import '../../../core/network/api_client.dart';
import '../feed_game_style.dart';

class FoursomeFeedApi {
  FoursomeFeedApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> list(
    String accessToken, {
    int page = 0,
    int pageSize = 20,
    String gameStyle = 'ALL',
  }) {
    return _apiClient.getJson(
      '/foursome-feed',
      bearerToken: accessToken,
      query: <String, String>{
        'page': '$page',
        'pageSize': '$pageSize',
        'gameStyle': gameStyle,
      },
    );
  }

  Future<Map<String, dynamic>> create({
    required String accessToken,
    required String courseName,
    String? city,
    String? state,
    required String roundDateIso,
    required String teeTime,
    required int spotsNeeded,
    required String gameStyle,
    String? handicapPreference,
    String? feeLabel,
    String? notes,
  }) {
    return _apiClient.postJson(
      '/foursome-feed',
      bearerToken: accessToken,
      body: foursomeFeedCreateBody(
        courseName: courseName,
        city: city,
        state: state,
        roundDateIso: roundDateIso,
        teeTime: teeTime,
        spotsNeeded: spotsNeeded,
        gameStyle: gameStyle,
        handicapPreference: handicapPreference,
        feeLabel: feeLabel,
        notes: notes,
      ),
    );
  }

  Future<Map<String, dynamic>> contact({
    required String accessToken,
    required String postId,
  }) {
    return _apiClient.postJson(
      '/foursome-feed/$postId/contact',
      bearerToken: accessToken,
      body: const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> reportPost({
    required String accessToken,
    required String postId,
    required String reason,
    String? details,
  }) {
    return _apiClient.postJson(
      '/foursome-feed/$postId/report',
      bearerToken: accessToken,
      body: <String, dynamic>{
        'reason': reason,
        if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      },
    );
  }
}
