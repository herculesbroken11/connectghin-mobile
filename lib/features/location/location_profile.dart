/// Profile fields used by Discover / GHINder (distance sorting needs coords or at least city).
abstract final class LocationProfile {
  static bool hasDiscoveryLocation(Map<String, dynamic> me) {
    final lat = me['locationLat'];
    final lng = me['locationLng'];
    double? la;
    double? ln;
    if (lat is num) {
      la = lat.toDouble();
    } else if (lat != null) {
      la = double.tryParse('$lat');
    }
    if (lng is num) {
      ln = lng.toDouble();
    } else if (lng != null) {
      ln = double.tryParse('$lng');
    }
    if (la != null && ln != null && (la.abs() > 1e-6 || ln.abs() > 1e-6)) {
      return true;
    }
    final city = (me['city'] as String?)?.trim();
    return city != null && city.isNotEmpty;
  }
}
