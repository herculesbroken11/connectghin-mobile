/// Shared demo assets matching React design (Unsplash URLs).
abstract final class DemoImages {
  static const String heroGolf =
      'https://images.unsplash.com/photo-1768396747921-5a18367415d2?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080';

  static const String sarah =
      'https://images.unsplash.com/photo-1672936830498-3e07f1ed3c02?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080';
  static const String michael =
      'https://images.unsplash.com/photo-1662954610383-64450aa24b82?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080';
  static const String emma =
      'https://images.unsplash.com/photo-1686605972745-619c86a6d1f2?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080';
  static const String david =
      'https://images.unsplash.com/photo-1693163487498-07bbd30067f6?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080';
}

class DemoGolfer {
  const DemoGolfer({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    required this.handicap,
    required this.image,
    required this.verified,
    this.distance,
    this.bio,
    this.homeCourse,
    this.preferences = const [],
  });

  final String id;
  final String name;
  final int age;
  final String city;
  final double handicap;
  final String image;
  final bool verified;
  final String? distance;
  final String? bio;
  final String? homeCourse;
  final List<String> preferences;
}

final List<DemoGolfer> demoGolfers = [
  const DemoGolfer(
    id: '1',
    name: 'Sarah Martinez',
    age: 28,
    city: 'San Francisco, CA',
    handicap: 14.2,
    image: DemoImages.sarah,
    verified: true,
    distance: '2.5 mi',
    bio:
        'Love playing early morning rounds. Looking for partners who enjoy a relaxed pace.',
    homeCourse: 'Harding Park',
    preferences: ['Relaxed pace', 'Social drinking', 'No smoking', 'Music OK'],
  ),
  const DemoGolfer(
    id: '2',
    name: 'Michael Chen',
    age: 32,
    city: 'Oakland, CA',
    handicap: 8.5,
    image: DemoImages.michael,
    verified: true,
    distance: '4.8 mi',
    bio:
        'Competitive player, always looking to improve. Weekend warrior at Pebble Beach.',
    homeCourse: 'Pebble Beach',
    preferences: ['Fast pace', 'Friendly competition', 'No smoking', 'Quiet rounds'],
  ),
  const DemoGolfer(
    id: '3',
    name: 'Emma Wilson',
    age: 26,
    city: 'Berkeley, CA',
    handicap: 19.8,
    image: DemoImages.emma,
    verified: false,
    distance: '6.2 mi',
    bio: 'Beginner golfer excited to learn and improve with patient partners!',
    homeCourse: 'Tilden Park',
    preferences: ['Relaxed pace', 'Just for fun', 'No drinking', 'No smoking'],
  ),
  const DemoGolfer(
    id: '4',
    name: 'David Park',
    age: 35,
    city: 'San Mateo, CA',
    handicap: 11.3,
    image: DemoImages.david,
    verified: true,
    distance: '8.1 mi',
    bio: 'Golf is my meditation. Play 3-4 times a week, always looking for new courses.',
    homeCourse: 'Crystal Springs',
    preferences: ['Moderate pace', 'Social', 'No smoking'],
  ),
];

/// React match modal "You" avatar.
const String demoSelfAvatarUrl =
    'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop';

DemoGolfer? demoGolferById(String id) {
  for (final g in demoGolfers) {
    if (g.id == id) return g;
  }
  return null;
}
