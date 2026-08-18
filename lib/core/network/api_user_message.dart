import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../app/app_messenger.dart';
import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import 'api_client.dart';
import 'nest_http_error.dart';

/// True when the user dismissed Google/Apple sign-in (no error UI needed).
bool isSignInCancelledError(Object error) {
  if (error is GoogleSignInException) {
    return error.code == GoogleSignInExceptionCode.canceled ||
        error.code == GoogleSignInExceptionCode.interrupted;
  }
  if (error is SignInWithAppleAuthorizationException) {
    return error.code == AuthorizationErrorCode.canceled;
  }
  final s = error.toString().toLowerCase();
  return s.contains('sign_in_canceled') ||
      s.contains('12501') ||
      s.contains('error 1001') ||
      s.contains('authorizationerrorcode.canceled') ||
      s.contains('the user canceled the authorization attempt');
}

String messageFromAppleSignInError(Object error) {
  if (isSignInCancelledError(error)) {
    return 'Sign-in was cancelled.';
  }
  if (error is SignInWithAppleNotSupportedException) {
    return 'Apple sign-in is not available on this device.';
  }
  if (error is SignInWithAppleAuthorizationException) {
    return 'Apple sign-in failed. Please try again.';
  }
  return messageFromApiError(error, fallback: 'Apple sign-in failed. Please try again.');
}

String messageFromGoogleSignInError(Object error) {
  const playShaHelp =
      'Google Sign-In failed for this Play Store install. '
      'In Google Play Console → App integrity → App signing, copy the '
      'App signing key certificate SHA-1 (not only the upload key). '
      'Add it in Firebase project connectghin-prod → Project settings → '
      'Your Android app (com.connectghin.app) → Add fingerprint. '
      'Wait a few minutes, then update/reinstall the app from Play.';

  if (error is GoogleSignInException) {
    switch (error.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return playShaHelp;
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Could not open Google sign-in. Try again with the app in the foreground.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Google account mismatch. Sign out of Google on this device and try again.';
      case GoogleSignInExceptionCode.canceled:
      case GoogleSignInExceptionCode.interrupted:
        return 'Sign-in was cancelled.';
      case GoogleSignInExceptionCode.unknownError:
        break;
    }
    final desc = error.description?.trim();
    if (desc != null && desc.isNotEmpty) {
      final lower = desc.toLowerCase();
      if (lower.contains('10') || lower.contains('developer_error') || lower.contains('sha')) {
        return playShaHelp;
      }
      return desc;
    }
  }
  final s = error.toString().toLowerCase();
  if (s.contains('developer_error') ||
      s.contains('apiexception: 10') ||
      s.contains('api_exception: 10') ||
      s.contains('code=10') ||
      s.contains('status{statuscode=10')) {
    return playShaHelp;
  }
  return messageFromApiError(error, fallback: 'Google sign-in failed. Please try again.');
}

/// Human-readable text from API failures (never raw JSON / `API 400: {...}`).
String messageFromApiError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is! ApiHttpException) {
    if (error is FormatException) {
      return 'Could not read the server response. Please try again.';
    }
    if (isSignInCancelledError(error)) {
      return 'Sign-in was cancelled.';
    }
    final s = '$error'
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^PlatformException\([^,]+,\s*'), '')
        .trim();
    if (s.startsWith('API ') && s.contains('{')) return fallback;
    return s.length > 200 ? fallback : s;
  }

  final e = error;
  final bl = e.body.toLowerCase();
  if (e.statusCode == 401) {
    if (bl.contains('unavailable') || bl.contains('suspended') || bl.contains('inactive')) {
      return 'This account is suspended or unavailable. You cannot sign in. Contact support if you believe this is a mistake.';
    }
    if (bl.contains('session') || bl.contains('refresh token')) {
      return 'Your session expired. Please sign in again.';
    }
    if (bl.contains('google')) {
      return 'Google sign-in failed. Please try again.';
    }
    if (bl.contains('apple')) {
      return 'Apple sign-in failed. Please try again.';
    }
  }
  if (e.statusCode == 503 && bl.contains('google')) {
    return 'Google sign-in is not available right now. Please use email login.';
  }
  if (e.statusCode == 503 && bl.contains('apple')) {
    return 'Apple sign-in is not available right now. Please use email login.';
  }

  final payload = parseNestHttpErrorBody(e.body);
  if (payload != null) {
    final extracted = _extractUserTextFromPayload(payload);
    if (extracted != null && extracted.isNotEmpty) return extracted;
  }

  switch (e.statusCode) {
    case 401:
      return 'Invalid email or password.';
    case 400:
      return 'Please check your information and try again.';
    case 403:
      if (isMessagingPremiumUpsell(e)) {
        return 'Premium lets you message golfers before you match. View plans to upgrade.';
      }
      return 'You can\'t do that with your current account.';
    case 404:
      return 'That wasn\'t found.';
    case 413:
      return 'That photo is too large. Please choose a smaller image.';
    default:
      if (e.statusCode >= 500) return 'Server error. Please try again later.';
      if (bl.contains('too large') || bl.contains('entity too large')) {
        return 'That photo is too large. Please choose a smaller image.';
      }
      return fallback;
  }
}

String? _extractUserTextFromPayload(Map<String, dynamic> map) {
  final m = map['message'];
  if (m is String && m.trim().isNotEmpty) return m.trim();
  if (m is List) {
    final parts = <String>[];
    for (final x in m) {
      if (x is String && x.trim().isNotEmpty) parts.add(_sentenceCaseValidation(x.trim()));
    }
    if (parts.isNotEmpty) return parts.join('\n');
  }
  return null;
}

/// "email must be an email" -> "Email must be an email"
String _sentenceCaseValidation(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// True when backend blocked starting a chat without a match (premium upsell).
bool isMessagingPremiumUpsell(Object error) {
  if (error is! ApiHttpException || error.statusCode != 403) return false;
  return error.body.toLowerCase().contains('match required');
}

/// Toast-style floating bar (Material SnackBar works well on Android and iOS).
void showApiErrorSnackBar(BuildContext context, Object error, {String? prefix}) {
  if (isMessagingPremiumUpsell(error)) {
    final messenger =
        ScaffoldMessenger.maybeOf(context) ?? rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          messageFromApiError(error),
          style: const TextStyle(color: CgColors.white, fontSize: 15, height: 1.35),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: CgColors.gray900,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View plans',
          textColor: CgColors.green100,
          onPressed: () => context.push(AppPaths.appMembership),
        ),
      ),
    );
    return;
  }
  showUserMessageSnackBar(
    context,
    messageFromApiError(error),
    prefix: prefix,
  );
}

void showUserMessageSnackBar(BuildContext context, String message, {String? prefix}) {
  final messenger =
      ScaffoldMessenger.maybeOf(context) ?? rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  final msg = (prefix != null && prefix.isNotEmpty) ? '$prefix$message' : message;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: CgColors.white, fontSize: 15, height: 1.35)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: CgColors.gray900,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    ),
  );
}
