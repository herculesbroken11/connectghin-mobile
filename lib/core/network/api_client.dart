import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown when the API returns a non-success status (after optional refresh retry).
class ApiHttpException implements Exception {
  ApiHttpException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'API $statusCode: $body';
}

typedef OnTokensRefreshed = Future<void> Function(String accessToken, String refreshToken);

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.getAccessToken,
    this.getRefreshToken,
    this.onTokensRefreshed,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// When set, authenticated requests use this if [bearerToken] is null. Retries after refresh use the latest value.
  final String? Function()? getAccessToken;

  final String? Function()? getRefreshToken;
  final OnTokensRefreshed? onTokensRefreshed;

  Future<bool>? _refreshFuture;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$base').replace(queryParameters: query);
  }

  String? _effectiveBearer(String? explicit) => explicit ?? getAccessToken?.call();

  bool _shouldTryRefresh(String path) {
    if (getRefreshToken == null || onTokensRefreshed == null) return false;
    if (path.startsWith('/auth/login') ||
        path.startsWith('/auth/register') ||
        path.startsWith('/auth/refresh') ||
        path.startsWith('/auth/google') ||
        path.startsWith('/auth/apple')) {
      return false;
    }
    return true;
  }

  Future<bool> _tryRefreshTokens() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }
    _refreshFuture = _performRefresh();
    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<bool> _performRefresh() async {
    final rt = getRefreshToken?.call();
    final persist = onTokensRefreshed;
    if (rt == null || rt.isEmpty || persist == null) return false;
    try {
      final response = await _client.post(
        _uri('/auth/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'refreshToken': rt}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;
      final a = decoded['accessToken'] as String?;
      final r = decoded['refreshToken'] as String?;
      if (a == null || r == null) return false;
      await persist(a, r);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _getWithRetry(String path, {Map<String, String>? query, String? bearerToken}) async {
    String? b() => _effectiveBearer(bearerToken);
    var response = await _client.get(_uri(path, query), headers: _headers(b()));
    if (response.statusCode == 401 && _shouldTryRefresh(path)) {
      final ok = await _tryRefreshTokens();
      if (ok) {
        response = await _client.get(_uri(path, query), headers: _headers(b()));
      }
    }
    _throwIfNotOk(response);
    return response;
  }

  Future<http.Response> _postWithRetry(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    String? b() => _effectiveBearer(bearerToken);
    var response = await _client.post(
      _uri(path),
      headers: _headers(b()),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    if (response.statusCode == 401 && _shouldTryRefresh(path)) {
      final ok = await _tryRefreshTokens();
      if (ok) {
        response = await _client.post(
          _uri(path),
          headers: _headers(b()),
          body: jsonEncode(body ?? <String, dynamic>{}),
        );
      }
    }
    _throwIfNotOk(response);
    return response;
  }

  Future<http.Response> _patchWithRetry(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    String? b() => _effectiveBearer(bearerToken);
    var response = await _client.patch(
      _uri(path),
      headers: _headers(b()),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    if (response.statusCode == 401 && _shouldTryRefresh(path)) {
      final ok = await _tryRefreshTokens();
      if (ok) {
        response = await _client.patch(
          _uri(path),
          headers: _headers(b()),
          body: jsonEncode(body ?? <String, dynamic>{}),
        );
      }
    }
    _throwIfNotOk(response);
    return response;
  }

  Future<http.Response> _deleteWithRetry(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    String? b() => _effectiveBearer(bearerToken);
    var response = await _client.delete(
      _uri(path),
      headers: _headers(b()),
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode == 401 && _shouldTryRefresh(path)) {
      final ok = await _tryRefreshTokens();
      if (ok) {
        response = await _client.delete(
          _uri(path),
          headers: _headers(b()),
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    _throwIfNotOk(response);
    return response;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? bearerToken,
  }) async {
    final response = await _getWithRetry(path, query: query, bearerToken: bearerToken);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object from $path');
    }
    return decoded;
  }

  /// For endpoints that may return JSON `null` (e.g. optional DB row).
  Future<Map<String, dynamic>?> getJsonObjectOrNull(
    String path, {
    Map<String, String>? query,
    String? bearerToken,
  }) async {
    final response = await _getWithRetry(path, query: query, bearerToken: bearerToken);
    final decoded = jsonDecode(response.body);
    if (decoded == null) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object or null from $path');
    }
    return decoded;
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? query,
    String? bearerToken,
  }) async {
    final response = await _getWithRetry(path, query: query, bearerToken: bearerToken);
    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw Exception('Expected JSON array from $path');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    final response = await _postWithRetry(path, body: body, bearerToken: bearerToken);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object from $path');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    final response = await _patchWithRetry(path, body: body, bearerToken: bearerToken);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object from $path');
    }
    return decoded;
  }

  Future<void> deleteJson(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    await _deleteWithRetry(path, body: body, bearerToken: bearerToken);
  }

  /// Multipart POST (e.g. file upload). Does not set `Content-Type`; the boundary is added by [http.MultipartRequest].
  Future<Map<String, dynamic>> postMultipartJson(
    String path, {
    required http.MultipartFile file,
    Map<String, String>? fields,
    String? bearerToken,
  }) async {
    String? b() => _effectiveBearer(bearerToken);

    Future<http.Response> sendOnce(String? token) async {
      final request = http.MultipartRequest('POST', _uri(path));
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      fields?.forEach((key, value) => request.fields[key] = value);
      request.files.add(file);
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    }

    var response = await sendOnce(b());
    if (response.statusCode == 401 && _shouldTryRefresh(path)) {
      final ok = await _tryRefreshTokens();
      if (ok) {
        response = await sendOnce(b());
      }
    }
    _throwIfNotOk(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object from $path');
    }
    return decoded;
  }

  Map<String, String> _headers(String? bearerToken) {
    return <String, String>{
      'Content-Type': 'application/json',
      if (bearerToken != null && bearerToken.isNotEmpty) 'Authorization': 'Bearer $bearerToken',
    };
  }

  void _throwIfNotOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw ApiHttpException(response.statusCode, response.body);
  }
}
