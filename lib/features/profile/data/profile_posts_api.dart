import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../profile_post_image.dart';
import '../profile_post_submit.dart';

class ProfilePostsApi {
  ProfilePostsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> listForUser(
    String accessToken,
    String userId, {
    int page = 0,
    int pageSize = 20,
  }) {
    return _apiClient.getJson(
      '/profile-posts/users/$userId',
      bearerToken: accessToken,
      query: <String, String>{
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
  }

  Future<Map<String, dynamic>> createText({
    required String accessToken,
    required String body,
  }) {
    return _apiClient.postJson(
      '/profile-posts',
      bearerToken: accessToken,
      body: <String, dynamic>{'body': body},
    );
  }

  /// Reads image bytes in memory. iOS photo-library files are often HEIC,
  /// extension-less, or temporary paths that are gone by the time a path
  /// upload starts.
  Future<Map<String, dynamic>> createWithImage({
    required String accessToken,
    required List<int> bytes,
    required String filename,
    String? body,
  }) async {
    final file = await profilePostImageFile(bytes: bytes, filename: filename);
    return _apiClient.postMultipartJson(
      '/profile-posts/upload',
      file: file,
      fields: <String, String>{
        if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
      },
      bearerToken: accessToken,
    );
  }

  Future<void> deletePost({
    required String accessToken,
    required String postId,
  }) {
    return _apiClient.deleteJson('/profile-posts/$postId', bearerToken: accessToken);
  }
}

/// Filename and content type follow the bytes actually uploaded.
String profilePostUploadFilename(List<int> bytes) {
  if (profilePostBytesArePng(bytes)) return 'photo.png';
  if (profilePostBytesAreWebp(bytes)) return 'photo.webp';
  if (profilePostBytesAreGif(bytes)) return 'photo.gif';
  return 'photo.jpg';
}

MediaType profilePostContentType(String filename) {
  if (filename.endsWith('.png')) return MediaType('image', 'png');
  if (filename.endsWith('.webp')) return MediaType('image', 'webp');
  if (filename.endsWith('.gif')) return MediaType('image', 'gif');
  return MediaType('image', 'jpeg');
}

/// Builds the multipart file. HEIC/HEIF is decoded and re-encoded as JPEG first.
/// [decodeHeic] replaces ImageIO in tests; production uses [decodeProfilePostBitmapWithEngine].
Future<http.MultipartFile> profilePostImageFile({
  required List<int> bytes,
  required String filename,
  ProfilePostBitmapDecoder? decodeHeic,
}) async {
  if (bytes.isEmpty) {
    throw const ProfilePostFailure(
      'That photo could not be read. Please try another image.',
    );
  }
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final Uint8List payload;
  if (profilePostBytesAreHeic(data)) {
    payload = await transcodeProfilePostHeicToJpeg(data, decodeHeic: decodeHeic);
  } else if (!profilePostBytesAreJpeg(data) &&
      !profilePostBytesArePng(data) &&
      !profilePostBytesAreGif(data) &&
      !profilePostBytesAreWebp(data)) {
    throw const ProfilePostFailure(
      'That photo could not be read. Please try another image.',
    );
  } else {
    payload = data;
  }
  final safe = profilePostUploadFilename(payload);
  return http.MultipartFile.fromBytes(
    'file',
    payload,
    filename: safe,
    contentType: profilePostContentType(safe),
  );
}

class ProfilePostItem {
  const ProfilePostItem({
    required this.id,
    required this.userId,
    this.body,
    this.imageUrl,
    required this.createdAt,
    required this.isOwn,
  });

  final String id;
  final String userId;
  final String? body;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isOwn;

  static ProfilePostItem? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final userId = json['userId'] as String?;
    if (id == null || userId == null) return null;
    final createdRaw = json['createdAt'] as String?;
    return ProfilePostItem(
      id: id,
      userId: userId,
      body: json['body'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdAt: createdRaw != null ? DateTime.tryParse(createdRaw) ?? DateTime.now() : DateTime.now(),
      isOwn: json['isOwn'] == true,
    );
  }
}
