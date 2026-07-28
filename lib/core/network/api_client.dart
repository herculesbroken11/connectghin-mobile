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
typedef OnAuthFailure = Future<void> Function(String reason);

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.getAccessToken,
    this.getRefreshToken,
    this.onTokensRefreshed,
    this.onAuthFailure,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Always prefer the live session token so retries after refresh do not reuse a stale capture.
  final String? Function()? getAccessToken;

  final String? Function()? getRefreshToken;
  final OnTokensRefreshed? onTokensRefreshed;

  /// Invoked when refresh fails (or session is invalidated) so the app can sign the user out.
  final OnAuthFailure? onAuthFailure;

  Future<bool>? _refreshFuture;
  bool _authFailureInFlight = false;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$base').replace(queryParameters: query);
  }

  /// Prefer the latest session access token over any explicitly captured bearer.
  String? _effectiveBearer(String? explicit) {
    final latest = getAccessToken?.call();
    if (latest != null && latest.isNotEmpty) return latest;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return null;
  }

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

  Future<void> _notifyAuthFailure(String reason) async {
    if (_authFailureInFlight) return;
    final cb = onAuthFailure;
    if (cb == null) return;
    _authFailureInFlight = true;
    try {
      await cb(reason);
    } catch (_) {
      /* ignore */
    } finally {
      _authFailureInFlight = false;
    }
  }

  bool _looksLikeInvalidSession(String body) {
    final b = body.toLowerCase();
    return b.contains('session invalidated') ||
        b.contains('refresh token invalidated') ||
        b.contains('invalid or inactive') ||
        b.contains('account unavailable') ||
        b.contains('unauthorized');
  }

  Future<http.Response> _handleUnauthorizedRetry({
    required String path,
    required Future<http.Response> Function() send,
    required http.Response first,
  }) async {
    if (first.statusCode != 401 || !_shouldTryRefresh(path)) {
      return first;
    }
    final ok = await _tryRefreshTokens();
    if (!ok) {
      await _notifyAuthFailure('refresh_failed');
      return first;
    }
    final second = await send();
    if (second.statusCode == 401 && _looksLikeInvalidSession(second.body)) {
      await _notifyAuthFailure('session_invalidated');
    }
    return second;
  }

  Future<http.Response> _getWithRetry(String path, {Map<String, String>? query, String? bearerToken}) async {
    Future<http.Response> send() => _client.get(_uri(path, query), headers: _headers(_effectiveBearer(bearerToken)));
    final first = await send();
    final response = await _handleUnauthorizedRetry(path: path, send: send, first: first);
    _throwIfNotOk(response);
    return response;
  }

  Future<http.Response> _postWithRetry(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    Future<http.Response> send() => _client.post(
          _uri(path),
          headers: _headers(_effectiveBearer(bearerToken)),
          body: jsonEncode(body ?? <String, dynamic>{}),
        );
    final first = await send();
    final response = await _handleUnauthorizedRetry(path: path, send: send, first: first);
    _throwIfNotOk(response);
    return response;
  }

  Future<http.Response> _patchWithRetry(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    Future<http.Response> send() => _client.patch(
          _uri(path),
          headers: _headers(_effectiveBearer(bearerToken)),
          body: jsonEncode(body ?? <String, dynamic>{}),
        );
    final first = await send();
    final response = await _handleUnauthorizedRetry(path: path, send: send, first: first);
    _throwIfNotOk(response);
    return response;
  }

  Future<http.Response> _deleteWithRetry(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
  }) async {
    Future<http.Response> send() => _client.delete(
          _uri(path),
          headers: _headers(_effectiveBearer(bearerToken)),
          body: body != null ? jsonEncode(body) : null,
        );
    final first = await send();
    final response = await _handleUnauthorizedRetry(path: path, send: send, first: first);
    _throwIfNotOk(response);
    return response;
  }

  /// Nest/Prisma may return HTTP 200 with an empty body when there is no row (e.g. no GHIN request yet).
  static dynamic _decodeJsonBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    return jsonDecode(trimmed);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    String? bearerToken,
  }) async {
    final response = await _getWithRetry(path, query: query, bearerToken: bearerToken);
    final decoded = _decodeJsonBody(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected JSON object from $path');
    }
    return decoded;
  }

  /// For endpoints that may return JSON `null` or an empty body (no verification row yet).
  Future<Map<String, dynamic>?> getJsonObjectOrNull(
    String path, {
    Map<String, String>? query,
    String? bearerToken,
  }) async {
    final response = await _getWithRetry(path, query: query, bearerToken: bearerToken);
    final decoded = _decodeJsonBody(response.body);
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
    final decoded = _decodeJsonBody(response.body);
    if (decoded == null) {
      return <String, dynamic>{};
    }
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
    final decoded = _decodeJsonBody(response.body);
    if (decoded == null) {
      return <String, dynamic>{};
    }
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
    Future<http.Response> sendOnce() async {
      final request = http.MultipartRequest('POST', _uri(path));
      final token = _effectiveBearer(bearerToken);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      fields?.forEach((key, value) => request.fields[key] = value);
      request.files.add(file);
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    }

    final first = await sendOnce();
    final response = await _handleUnauthorizedRetry(path: path, send: sendOnce, first: first);
    _throwIfNotOk(response);
    final decoded = _decodeJsonBody(response.body);
    if (decoded == null) {
      return <String, dynamic>{};
    }
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
