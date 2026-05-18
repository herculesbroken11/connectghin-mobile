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
  }) {
    final q = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      'excludeSwiped': '$excludeSwiped',
      if (verifiedOnly != null) 'verifiedOnly': '$verifiedOnly',
      if (handicapMin != null) 'handicapMin': '$handicapMin',
      if (handicapMax != null) 'handicapMax': '$handicapMax',
    };
    return _apiClient.getJsonList('/discovery/candidates', query: q, bearerToken: accessToken);
  }
}
