import 'package:connectghin_flutter/features/auth/apple_sign_in_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple nonce SHA-256 is hex and stable', () {
    const raw = 'connectghin-apple-nonce-test';
    final hash = AppleSignInHelper.sha256ofString(raw);
    expect(hash, hasLength(64));
    expect(hash, AppleSignInHelper.sha256ofString(raw));
    expect(hash, isNot(AppleSignInHelper.sha256ofString('$raw!')));
  });

  test('Apple nonce generator returns URL-safe characters', () {
    final nonce = AppleSignInHelper.generateNonce();
    expect(nonce, hasLength(32));
    expect(RegExp(r'^[0-9A-Za-z._-]+$').hasMatch(nonce), isTrue);
  });
}
