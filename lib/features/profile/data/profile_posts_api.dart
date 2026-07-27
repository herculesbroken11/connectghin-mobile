import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';

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

  Future<Map<String, dynamic>> createWithImage({
    required String accessToken,
    required String filePath,
    String? body,
  }) async {
    final file = await http.MultipartFile.fromPath('file', filePath);
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
