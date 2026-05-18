import 'package:connectghin_flutter/core/network/api_client.dart';
import 'package:connectghin_flutter/core/network/api_user_message.dart';
import 'package:connectghin_flutter/core/network/nest_http_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseNestHttpErrorBody unwraps object message from HttpExceptionFilter', () {
    const body =
        '{"statusCode":403,"message":{"code":"DAILY_SWIPE_LIMIT","limit":10,"used":10},"path":"/api/v1/swipes","timestamp":"2026-01-01T00:00:00.000Z"}';
    final m = parseNestHttpErrorBody(body);
    expect(m, isNotNull);
    expect(m!['code'], 'DAILY_SWIPE_LIMIT');
    expect(m['limit'], 10);
    expect(m['used'], 10);
  });

  test('parseNestHttpErrorBody returns root when message is a string', () {
    const body = '{"statusCode":400,"message":"Email or username already in use","path":"/x","timestamp":"t"}';
    final m = parseNestHttpErrorBody(body);
    expect(m, isNotNull);
    expect(m!['message'], 'Email or username already in use');
  });

  test('ApiHttpException body works with parseNestHttpErrorBody', () {
    const body =
        '{"statusCode":403,"message":{"code":"DAILY_SWIPE_LIMIT","limit":10,"used":7},"path":"/swipes","timestamp":"t"}';
    final ex = ApiHttpException(403, body);
    final m = parseNestHttpErrorBody(ex.body);
    expect(m?['code'], 'DAILY_SWIPE_LIMIT');
    expect(m?['used'], 7);
  });

  test('messageFromApiError extracts class-validator messages from Nest filter body', () {
    const body =
        '{"statusCode":400,"message":{"message":["email must be an email"],"error":"Bad Request","statusCode":400},"path":"/api/v1/auth/login","timestamp":"2026-04-13T03:01:34.022Z"}';
    final msg = messageFromApiError(ApiHttpException(400, body));
    expect(msg, 'Email must be an email');
  });
}
