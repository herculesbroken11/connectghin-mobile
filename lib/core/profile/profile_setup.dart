import '../../app/router/app_paths.dart';

/// Whether the account may use the main app (Home / Discover / etc.).
/// Requires core onboarding fields and at least 2 profile photos.
bool isProfileSetupComplete(Map<String, dynamic> me) {
  final user = me['user'] as Map<String, dynamic>?;
  final photos = user?['profilePhotos'] as List<dynamic>? ?? const [];
  if (photos.length < 2) return false;

  final name = (me['displayName'] as String?)?.trim() ?? '';
  if (name.length < 2) return false;

  final ageRaw = me['age'];
  final age = ageRaw is int ? ageRaw : int.tryParse('$ageRaw');
  if (age == null || age < 18) return false;

  final city = (me['city'] as String?)?.trim() ?? '';
  final state = (me['state'] as String?)?.trim() ?? '';
  if (city.isEmpty && state.isEmpty) return false;

  final looking = (me['lookingFor'] as String?)?.trim() ?? '';
  if (looking.isEmpty) return false;

  final hasGolf = me['handicap'] != null ||
      ((me['homeCourse'] as String?)?.trim().isNotEmpty == true) ||
      ((me['skillLevel'] as String?)?.trim().isNotEmpty == true);
  if (!hasGolf) return false;

  return true;
}

/// Resume onboarding at the first incomplete step.
String suggestedOnboardingPath(Map<String, dynamic> me) {
  final name = (me['displayName'] as String?)?.trim() ?? '';
  final ageRaw = me['age'];
  final age = ageRaw is int ? ageRaw : int.tryParse('$ageRaw');
  final city = (me['city'] as String?)?.trim() ?? '';
  final state = (me['state'] as String?)?.trim() ?? '';
  if (name.length < 2 || age == null || age < 18 || (city.isEmpty && state.isEmpty)) {
    return AppPaths.onboardingBasic;
  }

  final hasGolf = me['handicap'] != null ||
      ((me['homeCourse'] as String?)?.trim().isNotEmpty == true) ||
      ((me['skillLevel'] as String?)?.trim().isNotEmpty == true);
  if (!hasGolf) return AppPaths.onboardingGolf;

  final looking = (me['lookingFor'] as String?)?.trim() ?? '';
  if (looking.isEmpty) return AppPaths.onboardingPreferences;

  final user = me['user'] as Map<String, dynamic>?;
  final photos = user?['profilePhotos'] as List<dynamic>? ?? const [];
  if (photos.length < 2) return AppPaths.onboardingPhotos;

  return AppPaths.onboardingPhotos;
}
