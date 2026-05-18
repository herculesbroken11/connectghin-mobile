import '../../../core/network/api_client.dart';

class VerificationApi {
  VerificationApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getStatus(String accessToken) {
    return _apiClient.getJson('/ghin-verification/me', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>> submitRequest({
    required String accessToken,
    required String ghinNumber,
    String? submittedFirstName,
    String? submittedLastName,
  }) {
    return _apiClient.postJson(
      '/ghin-verification/request',
      bearerToken: accessToken,
      body: <String, dynamic>{
        'ghinNumber': ghinNumber,
        if (submittedFirstName != null && submittedFirstName.trim().isNotEmpty)
          'submittedFirstName': submittedFirstName.trim(),
        if (submittedLastName != null && submittedLastName.trim().isNotEmpty)
          'submittedLastName': submittedLastName.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> appeal({
    required String accessToken,
    required String appealNote,
  }) {
    return _apiClient.postJson(
      '/ghin-verification/appeal',
      bearerToken: accessToken,
      body: <String, dynamic>{'appealNote': appealNote},
    );
  }
}
