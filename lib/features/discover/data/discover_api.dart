import '../../../core/network/api_client.dart';

class DiscoverApi {
  DiscoverApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> candidates(
    String accessToken, {
    int page = 0,
    int pageSize = 50,
    bool? verifiedOnly,
    bool excludeSwiped = true,
    double? handicapMin,
    double? handicapMax,
    double? maxDistanceMiles,
    String? skillLevel,
    String? playFrequency,
    String? musicPreference,
    String? drinkingPreference,
    String? smokingPreference,
    String? friendly420,
  }) {
    final q = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      'excludeSwiped': '$excludeSwiped',
      if (verifiedOnly != null) 'verifiedOnly': '$verifiedOnly',
      if (handicapMin != null) 'handicapMin': '$handicapMin',
      if (handicapMax != null) 'handicapMax': '$handicapMax',
      if (maxDistanceMiles != null) 'maxDistanceMiles': '$maxDistanceMiles',
      if (skillLevel != null && skillLevel.isNotEmpty) 'skillLevel': skillLevel,
      if (playFrequency != null && playFrequency.isNotEmpty) 'playFrequency': playFrequency,
      if (musicPreference != null && musicPreference.isNotEmpty) 'musicPreference': musicPreference,
      if (drinkingPreference != null && drinkingPreference.isNotEmpty)
        'drinkingPreference': drinkingPreference,
      if (smokingPreference != null && smokingPreference.isNotEmpty)
        'smokingPreference': smokingPreference,
      if (friendly420 != null && friendly420.isNotEmpty) 'friendly420': friendly420,
    };
    return _apiClient.getJsonList('/discovery/candidates', query: q, bearerToken: accessToken);
  }
}
