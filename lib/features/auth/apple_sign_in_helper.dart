import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignInResult {
  const AppleSignInResult({
    required this.identityToken,
    required this.rawNonce,
    this.email,
    this.fullName,
  });

  final String identityToken;
  final String rawNonce;
  final String? email;
  final String? fullName;
}

/// Sign in with Apple for iPhone / iPad (required when Google login is offered).
abstract final class AppleSignInHelper {
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

  static Future<AppleSignInResult> obtainCredential() async {
    final rawNonce = generateNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: sha256ofString(rawNonce),
    );
    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Apple sign-in did not return an identity token');
    }
    final given = credential.givenName?.trim() ?? '';
    final family = credential.familyName?.trim() ?? '';
    final fullName = [given, family].where((p) => p.isNotEmpty).join(' ');
    return AppleSignInResult(
      identityToken: idToken,
      rawNonce: rawNonce,
      email: credential.email,
      fullName: fullName.isEmpty ? null : fullName,
    );
  }

  static String generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  static String sha256ofString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}
