import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import 'api_client.dart';
import 'nest_http_error.dart';

/// True when the user dismissed Google/Apple sign-in (no error toast needed).
bool isSignInCancelledError(Object error) {
  final s = error.toString().toLowerCase();
  return s.contains('cancel') ||
      s.contains('aborted') ||
      s.contains('12501') ||
      s.contains('sign_in_canceled');
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
    default:
      if (e.statusCode >= 500) return 'Server error. Please try again later.';
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
    final messenger = ScaffoldMessenger.maybeOf(context);
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
  final messenger = ScaffoldMessenger.maybeOf(context);
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
