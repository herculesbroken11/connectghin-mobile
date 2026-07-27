import 'package:geolocator/geolocator.dart';

import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../profiles/data/profiles_api.dart';

/// Requests OS location permission, reads coordinates, PATCHes `/profiles/me`.
class LocationDevice {
  LocationDevice._();

  static Future<String?> requestAndSaveToProfile(AuthSession session) async {
    final t = session.accessToken;
    if (t == null) return 'Not signed in';

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      await Geolocator.openLocationSettings();
      return 'Turn on location services and try again.';
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return 'Location permission denied.';
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return 'Enable location in system settings for Connectghin.';
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      await ProfilesApi(session.apiClient).updateMe(
        accessToken: t,
        body: <String, dynamic>{
          'locationLat': pos.latitude,
          'locationLng': pos.longitude,
        },
      );
      session.bumpProfileRefresh();
      return null;
    } catch (e) {
      return messageFromApiError(e);
    }
  }
}
