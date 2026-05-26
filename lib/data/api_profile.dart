import 'package:flutter/foundation.dart';

import '../core/network/api_image_url.dart';

String? _firstProfilePhotoUrl(List<dynamic>? photos) {
  if (photos == null || photos.isEmpty) return null;
  for (final p in _sortProfilePhotos(photos)) {
    final resolved = ApiImageUrl.resolve(p['imageUrl'] as String?);
    if (resolved != null) return resolved;
  }
  return null;
}

List<Map<String, dynamic>> _sortProfilePhotos(List<dynamic> photos) {
  final maps = photos.whereType<Map<String, dynamic>>().toList();
  maps.sort((a, b) {
    final aPrimary = a['isPrimary'] == true ? 1 : 0;
    final bPrimary = b['isPrimary'] == true ? 1 : 0;
    if (aPrimary != bPrimary) return bPrimary.compareTo(aPrimary);
    final aOrder = a['sortOrder'] as int? ?? 0;
    final bOrder = b['sortOrder'] as int? ?? 0;
    return aOrder.compareTo(bOrder);
  });
  return maps;
}

List<String> _profilePhotoUrlList(Map<String, dynamic>? user) {
  final raw = user?['profilePhotos'] as List<dynamic>?;
  if (raw == null) return [];
  final urls = <String>[];
  for (final p in _sortProfilePhotos(raw)) {
    final resolved = ApiImageUrl.resolve(p['imageUrl'] as String?);
    if (resolved != null) urls.add(resolved);
  }
  return urls;
}

/// Normalized card row from discovery / matches / conversation participants.
@immutable
class ApiGolferCard {
  const ApiGolferCard({
    required this.userId,
    required this.displayName,
    required this.age,
    required this.cityLine,
    required this.handicap,
    this.distanceMiles,
    required this.imageUrl,
    required this.verified,
    this.bio,
    this.homeCourse,
  });

  final String userId;
  final String displayName;
  final int? age;
  final String cityLine;
  final double? handicap;
  final double? distanceMiles;
  final String? imageUrl;
  final bool verified;
  final String? bio;
  final String? homeCourse;

  static double? parseDecimal(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static double? _parseDecimal(dynamic v) => parseDecimal(v);

  /// `GET /discovery/candidates` profile row (includes nested `user`).
  static ApiGolferCard? fromDiscoveryProfile(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final userId = (json['userId'] as String?) ?? (user?['id'] as String?);
    if (userId == null) return null;
    final photos = (user?['profilePhotos'] as List<dynamic>?) ?? (json['profilePhotos'] as List<dynamic>?);
    final imageUrl = _firstProfilePhotoUrl(photos);
    final city = json['city'] as String? ?? '';
    final state = json['state'] as String? ?? '';
    final distanceMiles = _parseDecimal(json['distanceMiles']);
    final distanceKm = _parseDecimal(json['distanceKm']);
    final cityLine = [city, state].where((s) => s.isNotEmpty).join(', ');
    return ApiGolferCard(
      userId: userId,
      displayName: json['displayName'] as String? ?? user?['username'] as String? ?? 'Golfer',
      age: json['age'] is int ? json['age'] as int : int.tryParse('${json['age'] ?? ''}'),
      cityLine: cityLine.isEmpty ? 'Nearby' : cityLine,
      handicap: _parseDecimal(json['handicap']),
      distanceMiles: distanceMiles ?? (distanceKm != null ? distanceKm * 0.621371 : null),
      imageUrl: imageUrl,
      verified: json['isGHINVerified'] as bool? ?? false,
      bio: json['bio'] as String?,
      homeCourse: json['homeCourse'] as String?,
    );
  }

  /// `GET /matches` row with `userOne` / `userTwo` for viewer.
  static ApiGolferCard? fromMatch(Map<String, dynamic> json, String viewerId) {
    final u1 = json['userOne'] as Map<String, dynamic>?;
    final u2 = json['userTwo'] as Map<String, dynamic>?;
    if (u1 == null || u2 == null) return null;
    final other = (u1['id'] as String) == viewerId ? u2 : u1;
    return fromUserJson(other);
  }

  /// Tries discovery-shaped profile first, then a nested `user` participant shape.
  static ApiGolferCard? fromAnyProfileJson(Map<String, dynamic> json) {
    final a = fromDiscoveryProfile(json);
    if (a != null) {
      return a;
    }
    final u = json['user'] as Map<String, dynamic>?;
    if (u != null) {
      return fromUserJson(u);
    }
    return null;
  }

  /// Nested `user` from conversation participants (`profile` + `profilePhotos` on user).
  static ApiGolferCard? fromUserJson(Map<String, dynamic> user) {
    final id = user['id'] as String?;
    final profile = user['profile'] as Map<String, dynamic>?;
    if (id == null || profile == null) return null;
    final photos = user['profilePhotos'] as List<dynamic>?;
    final imageUrl = _firstProfilePhotoUrl(photos);
    final city = profile['city'] as String? ?? '';
    final state = profile['state'] as String? ?? '';
    final cityLine = [city, state].where((s) => s.isNotEmpty).join(', ');
    return ApiGolferCard(
      userId: id,
      displayName: profile['displayName'] as String? ?? user['username'] as String? ?? 'Golfer',
      age: profile['age'] as int?,
      cityLine: cityLine.isEmpty ? 'Nearby' : cityLine,
      handicap: _parseDecimal(profile['handicap']),
      distanceMiles: null,
      imageUrl: imageUrl,
      verified: profile['isGHINVerified'] as bool? ?? false,
      bio: profile['bio'] as String?,
      homeCourse: profile['homeCourse'] as String?,
    );
  }
}

/// `GET /profiles/:userId` — full public profile for the “view other user” screen.
@immutable
class OtherUserProfileDetail {
  const OtherUserProfileDetail({
    required this.userId,
    required this.displayName,
    required this.age,
    required this.cityLine,
    required this.handicap,
    required this.photoUrls,
    required this.verified,
    this.bio,
    this.homeCourse,
    this.lookingForTags = const [],
    this.drinkingPreference,
    this.smokingPreference,
    this.musicPreference,
    this.skillLevel,
    this.playFrequency,
    this.memberSince,
    this.distanceMilesHint,
  });

  final String userId;
  final String displayName;
  final int? age;
  final String cityLine;
  final double? handicap;
  final List<String> photoUrls;
  final bool verified;
  final String? bio;
  final String? homeCourse;
  final List<String> lookingForTags;
  final String? drinkingPreference;
  final String? smokingPreference;
  final String? musicPreference;
  final String? skillLevel;
  final String? playFrequency;
  final DateTime? memberSince;
  /// Optional miles string when passed from Discover/GHINder (e.g. `"2.5"`).
  final String? distanceMilesHint;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static List<String> _splitLookingFor(String? s) {
    if (s == null || s.trim().isEmpty) return [];
    return s
        .split(RegExp(r'[,;•·|]\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static OtherUserProfileDetail? fromPublicProfileJson(
    Map<String, dynamic> json, {
    String? distanceMilesHint,
  }) {
    final userId = json['userId'] as String?;
    if (userId == null) return null;
    final user = json['user'] as Map<String, dynamic>?;
    final city = json['city'] as String? ?? '';
    final state = json['state'] as String? ?? '';
    final cityLine = [city, state].where((s) => s.isNotEmpty).join(', ');
    final age = json['age'] is int ? json['age'] as int : int.tryParse('${json['age'] ?? ''}');
    return OtherUserProfileDetail(
      userId: userId,
      displayName: json['displayName'] as String? ?? 'Golfer',
      age: age,
      cityLine: cityLine.isEmpty ? 'Nearby' : cityLine,
      handicap: ApiGolferCard.parseDecimal(json['handicap']),
      photoUrls: _profilePhotoUrlList(user),
      verified: json['isGHINVerified'] as bool? ?? false,
      bio: json['bio'] as String?,
      homeCourse: json['homeCourse'] as String?,
      lookingForTags: _splitLookingFor(json['lookingFor'] as String?),
      drinkingPreference: json['drinkingPreference'] as String?,
      smokingPreference: json['smokingPreference'] as String?,
      musicPreference: json['musicPreference'] as String?,
      skillLevel: json['skillLevel'] as String?,
      playFrequency: json['playFrequency'] as String?,
      memberSince: _parseDate(user?['createdAt']),
      distanceMilesHint: distanceMilesHint,
    );
  }
}
