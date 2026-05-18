import '../../../core/network/api_client.dart';

class AuthApi {
  AuthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
  }) {
    return _apiClient.postJson('/auth/register', body: <String, dynamic>{
      'email': email,
      'username': username,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _apiClient.postJson('/auth/login', body: <String, dynamic>{
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> loginWithGoogle({required String idToken}) {
    return _apiClient.postJson('/auth/google', body: <String, dynamic>{
      'idToken': idToken,
    });
  }

  Future<Map<String, dynamic>> loginWithApple({
    required String idToken,
    String? email,
  }) {
    return _apiClient.postJson('/auth/apple', body: <String, dynamic>{
      'idToken': idToken,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim().toLowerCase(),
    });
  }

  Future<Map<String, dynamic>> refresh({required String refreshToken}) {
    return _apiClient.postJson('/auth/refresh', body: <String, dynamic>{
      'refreshToken': refreshToken,
    });
  }

  Future<Map<String, dynamic>> me(String accessToken) {
    return _apiClient.getJson('/auth/me', bearerToken: accessToken);
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) {
    return _apiClient.postJson('/auth/forgot-password', body: <String, dynamic>{
      'email': email.trim().toLowerCase(),
    });
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) {
    return _apiClient.postJson('/auth/reset-password', body: <String, dynamic>{
      'token': token,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> requestMagicLink({required String email}) {
    return _apiClient.postJson('/auth/magic-link/request', body: <String, dynamic>{
      'email': email.trim().toLowerCase(),
    });
  }

  Future<Map<String, dynamic>> consumeMagicLink({required String token}) {
    return _apiClient.postJson('/auth/magic-link/consume', body: <String, dynamic>{
      'token': token,
    });
  }
}
