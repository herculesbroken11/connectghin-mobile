import 'env_config.dart';

/// OAuth / Places / API config. Resolution order: `--dart-define` â†’ synced `AppEnvValues` â†’ default.
abstract final class AppSecrets {
  /// Google OAuth Web client ID (public; same as backend `GOOGLE_OAUTH_CLIENT_ID`).
  static const String googleServerClientIdDefault =
      '97795397365-5mkjtqts7c4kpbp9bt9i4kt2tfcfcovr.apps.googleusercontent.com';

  static String get googleServerClientId {
    const defined = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    if (defined.trim().isNotEmpty) return defined.trim();
    return EnvConfig.get('GOOGLE_SERVER_CLIENT_ID') ?? googleServerClientIdDefault;
  }

  /// Optional: address autocomplete in onboarding only. Restrict key to **Places API** in Google Cloud.
  /// GPS / GHINder do not use this key.
  static String? get googlePlacesApiKey {
    const defined = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
    if (defined.trim().isNotEmpty) return defined.trim();
    return EnvConfig.get('GOOGLE_PLACES_API_KEY');
  }
}
