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

/// Parsed rating summary from API `ratingSummary` / `profileSummary` objects.
@immutable
class GolferRatingSummary {
  const GolferRatingSummary({
    this.averageRating,
    this.reviewCount = 0,
    this.averageHandicapAccuracy,
    this.averageSportsmanship,
    this.averagePaceOfPlay,
    this.playAgainPercent = 0,
  });

  final double? averageRating;
  final int reviewCount;
  final double? averageHandicapAccuracy;
  final double? averageSportsmanship;
  final double? averagePaceOfPlay;
  final int playAgainPercent;

  bool get hasRating => averageRating != null && averageRating! > 0 && reviewCount > 0;

  static GolferRatingSummary fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GolferRatingSummary();
    double? parseAvg(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');
    final avg = parseAvg(json['averageRating']);
    final countRaw = json['reviewCount'] ?? json['totalRatings'];
    final count = countRaw is int ? countRaw : int.tryParse('$countRaw') ?? 0;
    final playAgainRaw = json['playAgainPercent'];
    final playAgain = playAgainRaw is int ? playAgainRaw : int.tryParse('$playAgainRaw') ?? 0;
    return GolferRatingSummary(
      averageRating: avg,
      reviewCount: count,
      averageHandicapAccuracy: parseAvg(json['averageHandicapAccuracy']),
      averageSportsmanship: parseAvg(json['averageSportsmanship']),
      averagePaceOfPlay: parseAvg(json['averagePaceOfPlay']),
      playAgainPercent: playAgain,
    );
  }
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
    this.isPremium = false,
    this.rating = const GolferRatingSummary(),
    this.bio,
    this.homeCourse,
    this.skillLevel,
    this.playFrequency,
    this.smokingPreference,
    this.musicPreference,
    this.drinkingPreference,
  });

  final String userId;
  final String displayName;
  final int? age;
  final String cityLine;
  final double? handicap;
  final double? distanceMiles;
  final String? imageUrl;
  final bool verified;
  final bool isPremium;
  final GolferRatingSummary rating;
  final String? bio;
  final String? homeCourse;
  final String? skillLevel;
  final String? playFrequency;
  final String? smokingPreference;
  final String? musicPreference;
  final String? drinkingPreference;

  List<String> get preferenceChips {
    final chips = <String>[];
    void add(String? v) {
      final t = v?.trim();
      if (t != null && t.isNotEmpty) chips.add(t);
    }

    add(playFrequency);
    add(skillLevel);
    add(smokingPreference == 'No' ? 'No smoking' : smokingPreference);
    add(musicPreference);
    return chips.take(3).toList();
  }

  static double? parseDecimal(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static double? _parseDecimal(dynamic v) => parseDecimal(v);

  static bool _parsePremium(Map<String, dynamic> json, Map<String, dynamic>? user) {
    if (json['isPremium'] == true) return true;
    final mt = user?['membershipType'] as String? ?? json['membershipType'] as String?;
    return mt == 'PREMIUM';
  }

  static GolferRatingSummary _parseRating(Map<String, dynamic> json, Map<String, dynamic>? user) {
    final direct = GolferRatingSummary.fromJson(json['ratingSummary'] as Map<String, dynamic>?);
    if (direct.hasRating) return direct;
    return GolferRatingSummary.fromJson(user?['ratingSummary'] as Map<String, dynamic>?);
  }

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
      isPremium: _parsePremium(json, user),
      rating: _parseRating(json, user),
      bio: json['bio'] as String?,
      homeCourse: json['homeCourse'] as String?,
      skillLevel: json['skillLevel'] as String?,
      playFrequency: json['playFrequency'] as String?,
      smokingPreference: json['smokingPreference'] as String?,
      musicPreference: json['musicPreference'] as String?,
      drinkingPreference: json['drinkingPreference'] as String?,
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
      isPremium: _parsePremium(user, user),
      rating: _parseRating(user, user),
      bio: profile['bio'] as String?,
      homeCourse: profile['homeCourse'] as String?,
      skillLevel: profile['skillLevel'] as String?,
      playFrequency: profile['playFrequency'] as String?,
      smokingPreference: profile['smokingPreference'] as String?,
      musicPreference: profile['musicPreference'] as String?,
      drinkingPreference: profile['drinkingPreference'] as String?,
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
    this.isPremium = false,
    this.rating = const GolferRatingSummary(),
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
  final bool isPremium;
  final GolferRatingSummary rating;
  final String? bio;
  final String? homeCourse;
  final List<String> lookingForTags;
  final String? drinkingPreference;
  final String? smokingPreference;
  final String? musicPreference;
  final String? skillLevel;
  final String? playFrequency;
  final DateTime? memberSince;
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
      isPremium: json['isPremium'] == true || user?['membershipType'] == 'PREMIUM',
      rating: GolferRatingSummary.fromJson(json['ratingSummary'] as Map<String, dynamic>?),
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

/// Foursome feed post from `GET /foursome-feed`.
@immutable
class FoursomeFeedPost {
  const FoursomeFeedPost({
    required this.id,
    required this.posterId,
    required this.courseName,
    required this.locationLine,
    required this.roundDate,
    required this.teeTime,
    required this.spotsNeeded,
    required this.gameStyle,
    this.handicapPreference,
    this.feeLabel,
    this.notes,
    required this.status,
    required this.posterName,
    this.posterHandicap,
    this.posterImageUrl,
    this.posterVerified = false,
    this.posterPremium = false,
    this.posterRating = const GolferRatingSummary(),
    required this.createdAt,
  });

  final String id;
  final String posterId;
  final String courseName;
  final String locationLine;
  final DateTime roundDate;
  final String teeTime;
  final int spotsNeeded;
  final String gameStyle;
  final String? handicapPreference;
  final String? feeLabel;
  final String? notes;
  final String status;
  final String posterName;
  final double? posterHandicap;
  final String? posterImageUrl;
  final bool posterVerified;
  final bool posterPremium;
  final GolferRatingSummary posterRating;
  final DateTime createdAt;

  static FoursomeFeedPost? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;
    final poster = json['poster'] as Map<String, dynamic>?;
    final posterId = (json['posterId'] as String?) ?? (json['userId'] as String?) ?? poster?['id'] as String?;
    if (posterId == null) return null;

    final photos = poster?['profilePhotos'] as List<dynamic>?;
    final imageUrl = _firstProfilePhotoUrl(photos);
    final profile = poster?['profile'] as Map<String, dynamic>?;

    final city = json['city'] as String? ?? '';
    final state = json['state'] as String? ?? '';
    final location = json['location'] as String? ??
        [city, state].where((s) => s.isNotEmpty).join(', ');

    final roundDateRaw = json['roundDate'] ?? json['date'];
    final roundDate = roundDateRaw is String ? DateTime.tryParse(roundDateRaw) : null;
    if (roundDate == null) return null;

    final createdRaw = json['createdAt'] as String?;
    final createdAt = createdRaw != null ? DateTime.tryParse(createdRaw) ?? DateTime.now() : DateTime.now();

    return FoursomeFeedPost(
      id: id,
      posterId: posterId,
      courseName: json['courseName'] as String? ?? 'Course',
      locationLine: location.isEmpty ? 'Nearby' : location,
      roundDate: roundDate,
      teeTime: json['teeTime'] as String? ?? '',
      spotsNeeded: json['spotsNeeded'] is int
          ? json['spotsNeeded'] as int
          : int.tryParse('${json['spotsNeeded'] ?? 1}') ?? 1,
      gameStyle: json['gameStyle'] as String? ?? 'CASUAL',
      handicapPreference: json['handicapPreference'] as String?,
      feeLabel: json['feeLabel'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'OPEN',
      posterName: poster?['displayName'] as String? ??
          profile?['displayName'] as String? ??
          poster?['username'] as String? ??
          'Golfer',
      posterHandicap: ApiGolferCard.parseDecimal(profile?['handicap'] ?? poster?['handicap']),
      posterImageUrl: imageUrl,
      posterVerified: profile?['isGHINVerified'] == true || poster?['isGHINVerified'] == true,
      posterPremium: poster?['isPremium'] == true || poster?['membershipType'] == 'PREMIUM',
      posterRating: GolferRatingSummary.fromJson(poster?['ratingSummary'] as Map<String, dynamic>?),
      createdAt: createdAt,
    );
  }

  String get gameStyleLabel {
    switch (gameStyle.toUpperCase()) {
      case 'COMPETITIVE':
        return 'Competitive';
      case 'TOURNAMENT':
        return 'Tournament';
      case 'SERIOUS':
        return 'Serious';
      default:
        return 'Casual';
    }
  }
}
