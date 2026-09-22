/// Single source of truth for Premium benefits shown in the Flutter app.
/// Keep aligned with backend entitlements (swipes + foursome-feed).
class PremiumBenefits {
  PremiumBenefits._();

  static const List<(String title, String subtitle)> items = [
    ('Unlimited Connect likes', 'No daily limit on connection requests'),
    ('Full Feed access', 'Browse all open spots, not just a preview'),
    ('Post open spots', 'Publish rounds on The Feed for other golfers'),
    ('Contact from The Feed', 'Message golfers who posted open spots'),
    ('Premium badge', 'Show a Premium badge on your profile'),
  ];

  static const List<(String title, String subtitle)> manageItems = [
    ('Unlimited Connect likes', 'No daily limit on connection requests'),
    ('Full Feed access', 'Browse all open spots, not just a preview'),
    ('Post open spots', 'Publish rounds on The Feed for other golfers'),
    ('Contact from The Feed', 'Message golfers who posted open spots'),
  ];

  static const List<String> comparePremiumLines = [
    'Unlimited Connect likes',
    'Full Feed browse, post & contact',
    'Premium profile badge',
  ];

  static const List<String> compareFreeLines = [
    'Nearby golfer Connect (daily limit)',
    'Message after you match',
    'Feed preview (limited posts)',
  ];

  static const List<String> missingAfterExpiry = [
    'Unlimited Connect likes',
    'Full Feed access, posting, and contact',
    'Premium profile badge',
  ];

  static const String homePromoSubtitle =
      'Unlimited Connect likes, full Feed access, and more';
}
