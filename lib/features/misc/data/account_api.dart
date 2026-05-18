import '../../../core/network/api_client.dart';

class AccountApi {
  AccountApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) {
    return _apiClient.postJson(
      '/auth/change-password',
      bearerToken: accessToken,
      body: <String, dynamic>{
        'oldPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<Map<String, dynamic>> updateUsername({
    required String accessToken,
    required String username,
  }) {
    return _apiClient.patchJson(
      '/users/me',
      bearerToken: accessToken,
      body: <String, dynamic>{'username': username},
    );
  }

  Future<Map<String, dynamic>> checkUsernameAvailable({
    required String accessToken,
    required String username,
  }) {
    return _apiClient.getJson(
      '/users/username-available',
      query: <String, String>{'username': username},
      bearerToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> requestAccountDeletion({
    required String accessToken,
    String? reason,
  }) {
    return _apiClient.postJson(
      '/account/delete-request',
      bearerToken: accessToken,
      body: <String, dynamic>{if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
    );
  }

  Future<Map<String, dynamic>> getPrivacySettings(String accessToken) {
    return _apiClient.getJson('/privacy-settings/me', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>> updatePrivacySettings({
    required String accessToken,
    required Map<String, bool> body,
  }) {
    return _apiClient.patchJson('/privacy-settings/me', bearerToken: accessToken, body: body);
  }

  Future<Map<String, dynamic>> submitReport({
    required String accessToken,
    required String targetUserId,
    required String reason,
    String? details,
  }) {
    return _apiClient.postJson(
      '/reports',
      bearerToken: accessToken,
      body: <String, dynamic>{
        'targetUserId': targetUserId,
        'reason': reason,
        if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> blockUser({
    required String accessToken,
    required String blockedUserId,
  }) {
    return _apiClient.postJson(
      '/blocks',
      bearerToken: accessToken,
      body: <String, dynamic>{'blockedUserId': blockedUserId},
    );
  }

  Future<List<dynamic>> listBlockedUsers(String accessToken) {
    return _apiClient.getJsonList('/blocks', bearerToken: accessToken);
  }

  Future<void> unblockUser({
    required String accessToken,
    required String blockedUserId,
  }) {
    return _apiClient.deleteJson('/blocks/$blockedUserId', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>?> ghinStatus(String accessToken) {
    return _apiClient.getJsonObjectOrNull('/ghin-verification/me', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>> submitGhin({
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

  Future<Map<String, dynamic>> submitGhinAppeal({
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
