import 'package:connectghin_flutter/core/network/api_client.dart';
import 'package:connectghin_flutter/core/network/api_user_message.dart';
import 'package:connectghin_flutter/core/network/nest_http_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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

  test('messageFromApiError maps 413 photo uploads', () {
    final msg = messageFromApiError(ApiHttpException(413, '<html>413 Request Entity Too Large</html>'));
    expect(msg, 'That photo is too large. Please choose a smaller image.');
  });

  test('isSignInCancelledError treats Apple cancel as cancelled', () {
    const error = SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.canceled,
      message: 'The user canceled the authorization attempt',
    );
    expect(isSignInCancelledError(error), isTrue);
    expect(messageFromAppleSignInError(error), 'Sign-in was cancelled.');
  });

  test('messageFromApiError maps nested Invalid credentials to clear login copy', () {
    const body =
        '{"statusCode":401,"message":{"statusCode":401,"message":"Invalid credentials","error":"Unauthorized"},"path":"/api/v1/auth/login","timestamp":"t"}';
    final msg = messageFromApiError(ApiHttpException(401, body));
    expect(msg, 'Invalid email or password.');
  });

  test('messageFromApiError maps Account unavailable distinctly from bad password', () {
    const body =
        '{"statusCode":401,"message":{"statusCode":401,"message":"Account unavailable","error":"Unauthorized"},"path":"/api/v1/auth/login","timestamp":"t"}';
    final msg = messageFromApiError(ApiHttpException(401, body));
    expect(msg.toLowerCase(), contains('suspended'));
  });

  test('messageFromApiError maps network failures without Invalid credentials', () {
    final msg = messageFromApiError(Exception('SocketException: Failed host lookup'));
    expect(msg.toLowerCase(), contains('connection'));
    expect(msg.toLowerCase(), isNot(contains('invalid credentials')));
  });
}
