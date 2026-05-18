import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Backend REST base URL including `/api/v1` prefix.
///
/// Override per run, e.g.:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1`
/// - Android emulator → host machine: `http://10.0.2.2:3000/api/v1`
/// - iOS simulator / desktop → `http://localhost:3000/api/v1`
/// - Physical device → your LAN IP, e.g. `http://192.168.1.10:3000/api/v1`
abstract final class ApiConfig {
  static const String _defaultBaseUrl = 'http://10.0.2.2:3000/api/v1';

  static String get baseUrl {
    final envBase = _readDotenv('API_BASE_URL');
    if (envBase != null && envBase.isNotEmpty) {
      return envBase;
    }
    const defined = String.fromEnvironment('API_BASE_URL');
    if (defined.isNotEmpty) {
      return defined;
    }
    return _defaultBaseUrl;
  }

  /// WebSocket namespace URL for `ChatGateway` (`/chat`), derived from [baseUrl] origin.
  static String get socketChatUrl {
    final u = Uri.parse(baseUrl);
    final origin = Uri(scheme: u.scheme, host: u.host, port: u.hasPort ? u.port : null);
    return '${origin.toString().replaceAll(RegExp(r'/$'), '')}/chat';
  }

  static String? _readDotenv(String key) {
    try {
      if (!dotenv.isInitialized) {
        return null;
      }
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}
