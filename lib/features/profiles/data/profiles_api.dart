import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';

class ProfilesApi {
  ProfilesApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getMe(String accessToken) {
    return _apiClient.getJson('/profiles/me', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>> updateMe({
    required String accessToken,
    required Map<String, dynamic> body,
  }) {
    return _apiClient.patchJson('/profiles/me', body: body, bearerToken: accessToken);
  }

  Future<Map<String, dynamic>> getPublic({
    required String accessToken,
    required String userId,
  }) {
    return _apiClient.getJson('/profiles/$userId', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>> addPhoto({
    required String accessToken,
    required String imageUrl,
  }) {
    return _apiClient.postJson(
      '/profiles/me/photos',
      bearerToken: accessToken,
      body: <String, dynamic>{'imageUrl': imageUrl},
    );
  }

  Future<Map<String, dynamic>> uploadPhotoFile({
    required String accessToken,
    required String filePath,
  }) async {
    final file = await http.MultipartFile.fromPath('file', filePath);
    return _apiClient.postMultipartJson(
      '/profiles/me/photos/upload',
      file: file,
      bearerToken: accessToken,
    );
  }

  Future<void> deletePhoto({
    required String accessToken,
    required String photoId,
  }) {
    return _apiClient.deleteJson('/profiles/me/photos/$photoId', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>> reorderPhotos({
    required String accessToken,
    required List<String> orderedPhotoIds,
  }) {
    return _apiClient.patchJson(
      '/profiles/me/photos/reorder',
      bearerToken: accessToken,
      body: <String, dynamic>{'orderedPhotoIds': orderedPhotoIds},
    );
  }

  Future<Map<String, dynamic>> setPrimaryPhoto({
    required String accessToken,
    required String photoId,
  }) {
    return _apiClient.patchJson('/profiles/me/photos/$photoId/primary', bearerToken: accessToken);
  }
}
