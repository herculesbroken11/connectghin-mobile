/// Shared helpers for resolving effective Premium entitlement from API payloads.
/// Prefer the backend `isPremium` flag (includes admin override + store).
bool isEffectivePremiumFromJson(Map<String, dynamic>? json, {Map<String, dynamic>? user}) {
  if (json == null && user == null) return false;
  if (json?['isPremium'] == true) return true;
  if (user?['isPremium'] == true) return true;
  final mt = user?['membershipType'] as String? ?? json?['membershipType'] as String?;
  if (mt != 'PREMIUM') return false;
  final ms = user?['membershipStatus'] as String? ?? json?['membershipStatus'] as String?;
  return ms == 'ACTIVE' || ms == 'TRIALING' || ms == 'PAST_DUE';
}
