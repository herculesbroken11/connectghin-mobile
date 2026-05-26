import '../../generated/app_env.dart';

/// Values from `lib/generated/app_env.dart` (sync from `.env` via `tool/sync_env_to_asset.cmd`).
/// `--dart-define` still overrides via [AppSecrets] / [ApiConfig].
abstract final class EnvConfig {
  static Future<void> load() async {
    // No asset load — avoids Windows errno 32 on assets/env/config.env during build.
  }

  static String? get(String key) {
    switch (key) {
      case 'API_BASE_URL':
        return _nonEmpty(AppEnvValues.apiBaseUrl);
      case 'GOOGLE_SERVER_CLIENT_ID':
        return _nonEmpty(AppEnvValues.googleServerClientId);
      case 'GOOGLE_PLACES_API_KEY':
        return _nonEmpty(AppEnvValues.googlePlacesApiKey);
      default:
        return null;
    }
  }

  static String? _nonEmpty(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }
}
