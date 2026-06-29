import '../../../core/network/api_client.dart';

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
      body: <String, dynamic>{
        'courseName': courseName,
        if (city != null && city.isNotEmpty) 'city': city,
        if (state != null && state.isNotEmpty) 'state': state,
        'roundDate': roundDateIso,
        'teeTime': teeTime,
        'spotsNeeded': spotsNeeded,
        'gameStyle': gameStyle,
        if (handicapPreference != null && handicapPreference.isNotEmpty)
          'handicapPreference': handicapPreference,
        if (feeLabel != null && feeLabel.isNotEmpty) 'feeLabel': feeLabel,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
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
}
