import 'dart:convert';

/// Decodes JSON from [ApiHttpException.body] (or any Nest error response).
///
/// The global [HttpExceptionFilter] sends:
/// `{ "statusCode", "message", "path", "timestamp" }` where `message` is either
/// a string, an object (e.g. `{ "code": "..." }`), or a validation array.
/// When `message` is a [Map], returns that map so callers can read `code`, etc.
Map<String, dynamic>? parseNestHttpErrorBody(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    final msg = decoded['message'];
    if (msg is Map<String, dynamic>) return msg;
    return decoded;
  } catch (_) {
    return null;
  }
}
