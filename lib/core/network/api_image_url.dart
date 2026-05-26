import '../../app/config/api_config.dart';

/// Resolves profile photo URLs from the API (fixes localhost / relative paths).
abstract final class ApiImageUrl {
  static String? resolve(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final apiUri = Uri.parse(ApiConfig.baseUrl);
    final apiOrigin =
        Uri(scheme: apiUri.scheme, host: apiUri.host, port: apiUri.hasPort ? apiUri.port : null);

    // Relative upload path.
    if (trimmed.startsWith('/uploads/profile-photos/')) {
      return '${apiOrigin.toString()}/api/v1$trimmed';
    }
    if (trimmed.startsWith('/api/v1/uploads/profile-photos/')) {
      return '${apiOrigin.toString()}$trimmed';
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    final host = uri.host.toLowerCase();
    final isLocal = host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host.startsWith('192.168.');

    if (uri.path.contains('/uploads/profile-photos/') && isLocal) {
      return '${apiOrigin.toString()}${uri.path}';
    }

    // Non-upload https (e.g. Unsplash).
    if (uri.scheme == 'https' && !isLocal) {
      return trimmed;
    }

    if (uri.path.contains('/uploads/profile-photos/')) {
      return '${apiOrigin.toString()}${uri.path}';
    }

    return trimmed;
  }

  static List<String> resolveList(Iterable<String?> urls) {
    final out = <String>[];
    for (final u in urls) {
      final resolved = resolve(u);
      if (resolved != null && resolved.isNotEmpty) {
        out.add(resolved);
      }
    }
    return out;
  }
}
