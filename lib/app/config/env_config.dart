import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads optional keys from bundled [assetPath] (sync from root `.env` via `tool/sync_env_to_asset.ps1`).
abstract final class EnvConfig {
  static const String assetPath = 'assets/env/config.env';

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: assetPath);
    } catch (_) {
      // App still runs with --dart-define / [AppSecrets] defaults.
    }
  }

  static String? get(String key) {
    if (!dotenv.isInitialized) return null;
    final v = dotenv.env[key]?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }
}
