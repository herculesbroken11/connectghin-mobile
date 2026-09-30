import 'dart:developer' as developer;

import '../../core/network/api_client.dart';
import '../../core/network/api_user_message.dart';
import '../../core/network/nest_http_error.dart';

/// User-facing failure for the profile post composer. [message] is safe to show.
class ProfilePostFailure implements Exception {
  const ProfilePostFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Blocks a second tap until the in-flight post finishes.
class ProfilePostSubmitGate {
  bool _busy = false;

  bool get isBusy => _busy;

  /// Returns false when a post is already running.
  bool tryBegin() {
    if (_busy) return false;
    _busy = true;
    return true;
  }

  void finish() {
    _busy = false;
  }
}

bool isTermsAcceptanceRequired(Object error) {
  if (error is! ApiHttpException || error.statusCode != 403) return false;
  final payload = parseNestHttpErrorBody(error.body);
  final code = payload?['code']?.toString();
  if (code == 'TERMS_ACCEPTANCE_REQUIRED') return true;
  return error.body.toLowerCase().contains('terms_acceptance_required');
}

String profilePostFailureMessage(Object error) {
  if (error is ProfilePostFailure) return error.message;
  if (isTermsAcceptanceRequired(error)) {
    return 'Accept the Terms of Service to post.';
  }
  if (error is ApiHttpException && error.statusCode == 401) {
    return 'Your session expired. Please sign in again.';
  }
  if (error is ApiHttpException && error.statusCode == 413) {
    return 'That photo is too large. Please choose a smaller image.';
  }
  if (error is ApiHttpException && error.statusCode >= 500) {
    return 'Server error. Please try again later.';
  }
  return messageFromApiError(
    error,
    fallback: 'Could not post to your profile. Please try again.',
  );
}

void logProfilePostFailure(Object error) {
  developer.log('Profile post failed: $error', name: 'ProfilePost');
}

/// Sends a profile post after current Terms are accepted.
///
/// If the server still returns [isTermsAcceptanceRequired], the Terms step
/// runs again and the same post is retried once.
Future<void> submitProfilePost({
  required Future<bool> Function() ensureTerms,
  required Future<void> Function() send,
  bool Function(Object error) termsRequired = isTermsAcceptanceRequired,
}) async {
  if (!await ensureTerms()) {
    throw const ProfilePostFailure('Accept the Terms of Service to post.');
  }
  try {
    await send();
  } catch (error) {
    if (!termsRequired(error)) rethrow;
    if (!await ensureTerms()) {
      throw const ProfilePostFailure('Accept the Terms of Service to post.');
    }
    await send();
  }
}
