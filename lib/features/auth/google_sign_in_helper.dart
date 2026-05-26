import 'package:google_sign_in/google_sign_in.dart';

import '../../app/config/app_secrets.dart';

/// Google Sign-In for ConnectGHIN (Android/iOS release + debug).
abstract final class GoogleSignInHelper {
  static Future<void>? _init;
  static String? _initClientId;

  static Future<String> obtainIdToken({String? serverClientId}) async {
    final clientId = serverClientId ?? AppSecrets.googleServerClientId;
    if (clientId.isEmpty) {
      throw Exception('Google login is not configured for this build.');
    }
    if (_initClientId != clientId) {
      _initClientId = clientId;
      _init = GoogleSignIn.instance.initialize(serverClientId: clientId);
    }
    await _init;

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Google did not return a sign-in token. Please try again.',
      );
    }
    return idToken;
  }
}
