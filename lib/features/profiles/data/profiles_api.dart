import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

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

  /// iOS Simulator / PHPicker files often have no extension or a .HEIC name.
  /// Always send bytes with a real image filename so the API accepts the file.
  Future<Map<String, dynamic>> uploadPhotoFile({
    required String accessToken,
    required String filePath,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('That photo could not be read. Please try another image.');
    }
    final filename = _uploadFilename(filePath);
    final file = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: _contentType(filename),
    );
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

Future<XFile?> pickProfilePhoto(ImagePicker picker) {
  return picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 82,
    requestFullMetadata: false,
  );
}

String _uploadFilename(String filePath) {
  final lower = filePath.toLowerCase();
  if (lower.endsWith('.png')) return 'photo.png';
  if (lower.endsWith('.webp')) return 'photo.webp';
  if (lower.endsWith('.gif')) return 'photo.gif';
  return 'photo.jpg';
}

MediaType _contentType(String filename) {
  if (filename.endsWith('.png')) return MediaType('image', 'png');
  if (filename.endsWith('.webp')) return MediaType('image', 'webp');
  if (filename.endsWith('.gif')) return MediaType('image', 'gif');
  return MediaType('image', 'jpeg');
}
