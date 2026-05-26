import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_image_url.dart';
import '../../core/network/api_user_message.dart';
import '../../data/api_profile.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_text_field.dart';
import '../matches/data/matches_api.dart';
import '../messages/data/messages_api.dart';
import '../profiles/data/profiles_api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ApiGolferCard? _card;
  Map<String, dynamic>? _profileJson;
  Map<String, dynamic>? _userJson;
  int _matchCount = 0;
  bool _loading = true;
  String? _error;
  int _lastProfileTick = -1;
  String? _lastUserId;
  bool _sessionListenerAttached = false;

  /// Kept so [dispose] can removeListener without using [context] (unsafe after deactivation).
  AuthSession? _authSession;
  late final VoidCallback _onAuthSession;

  @override
  void initState() {
    super.initState();
    _onAuthSession = () {
      if (!mounted) return;
      final s = context.read<AuthSession>();
      if (s.userId != _lastUserId) {
        _lastUserId = s.userId;
        _lastProfileTick = s.profileRefreshTick;
        _load();
        return;
      }
      if (s.profileRefreshTick != _lastProfileTick) {
        _lastProfileTick = s.profileRefreshTick;
        _load();
      }
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authSession ??= context.read<AuthSession>();
    final session = _authSession!;
    if (!_sessionListenerAttached) {
      _sessionListenerAttached = true;
      _lastUserId = session.userId;
      _lastProfileTick = session.profileRefreshTick;
      session.addListener(_onAuthSession);
      _load();
    }
  }

  @override
  void dispose() {
    _authSession?.removeListener(_onAuthSession);
    super.dispose();
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _card = null;
          _profileJson = null;
          _userJson = null;
          _error = null;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ProfilesApi(session.apiClient);
      final matchesApi = MatchesApi(session.apiClient);
      final results = await Future.wait<Object>([
        api.getMe(t),
        matchesApi.list(t),
      ]);
      final profileJson = results[0] as Map<String, dynamic>;
      final matches = results[1] as List<dynamic>;
      final user = profileJson['user'] as Map<String, dynamic>?;
      final parsed = ApiGolferCard.fromDiscoveryProfile(profileJson);
      final preferredImage = _preferredProfileImageUrl(user);
      final card = parsed == null
          ? null
          : ApiGolferCard(
              userId: parsed.userId,
              displayName: parsed.displayName,
              age: parsed.age,
              cityLine: parsed.cityLine,
              handicap: parsed.handicap,
              distanceMiles: parsed.distanceMiles,
              imageUrl: preferredImage ?? parsed.imageUrl,
              verified: parsed.verified,
              bio: parsed.bio,
              homeCourse: parsed.homeCourse,
            );
      if (!mounted) return;
      setState(() {
        _profileJson = profileJson;
        _userJson = user;
        _card = card;
        _matchCount = matches.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = messageFromApiError(e);
        _loading = false;
      });
    }
  }

  ApiGolferCard? _fallbackCardFromProfile() {
    final p = _profileJson;
    if (p == null) return null;
    final user = _userJson;
    final imageUrl = _preferredProfileImageUrl(user);
    final uid = p['userId'] as String?;
    if (uid == null) return null;
    final city = p['city'] as String? ?? '';
    final state = p['state'] as String? ?? '';
    final cityLine = [city, state].where((s) => s.isNotEmpty).join(', ');
    return ApiGolferCard(
      userId: uid,
      displayName: p['displayName'] as String? ??
          user?['username'] as String? ??
          'Golfer',
      age:
          p['age'] is int ? p['age'] as int : int.tryParse('${p['age'] ?? ''}'),
      cityLine: cityLine.isEmpty ? 'Nearby' : cityLine,
      handicap: double.tryParse('${p['handicap'] ?? ''}'),
      imageUrl: imageUrl,
      verified: p['isGHINVerified'] == true,
      bio: p['bio'] as String?,
      homeCourse: p['homeCourse'] as String?,
    );
  }

  bool get _premium => (_userJson?['membershipType'] as String?) == 'PREMIUM';
  bool get _verified => _profileJson?['isGHINVerified'] as bool? ?? false;

  /// Primary first, then [sortOrder] — same order as header and gallery.
  List<String> _orderedProfilePhotoUrls(Map<String, dynamic>? user) {
    final photos =
        (user?['profilePhotos'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
    if (photos.isEmpty) return [];
    photos.sort((a, b) {
      final aPrimary = a['isPrimary'] == true ? 1 : 0;
      final bPrimary = b['isPrimary'] == true ? 1 : 0;
      if (aPrimary != bPrimary) return bPrimary.compareTo(aPrimary);
      final aOrder = a['sortOrder'] as int? ?? 0;
      final bOrder = b['sortOrder'] as int? ?? 0;
      return aOrder.compareTo(bOrder);
    });
    final urls = <String>[];
    for (final p in photos) {
      final url = ApiImageUrl.resolve(p['imageUrl'] as String?);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  String? _preferredProfileImageUrl(Map<String, dynamic>? user) {
    final urls = _orderedProfilePhotoUrls(user);
    return urls.isEmpty ? null : urls.first;
  }

  void _showProfilePhotoGallery(BuildContext context, List<String> urls,
      {int initialIndex = 0}) {
    if (urls.isEmpty) return;
    final i = initialIndex.clamp(0, urls.length - 1);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close photo',
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) {
        return SizedBox.expand(
          child: _ProfilePhotoGalleryPage(urls: urls, initialIndex: i),
        );
      },
    );
  }

  String _memberSinceLabel() {
    final iso = _profileJson?['createdAt'] as String?;
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      return '${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return '—';
    }
  }

  String _hcpLabel() {
    final h = _card?.handicap;
    if (h == null) return 'HCP';
    final t = h.toStringAsFixed(1);
    return '$t HCP';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_loading && _card == null) {
      return const Scaffold(
        backgroundColor: CgColors.gray50,
        body: Center(child: CircularProgressIndicator(color: CgColors.green700)),
      );
    }
    if (_error != null && _card == null) {
      return Scaffold(
        backgroundColor: CgColors.gray50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    final g = _card ?? _fallbackCardFromProfile();
    if (g == null) {
      return Scaffold(
        backgroundColor: CgColors.gray50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Unable to load profile details right now.',
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                CgPrimaryButton(
                    label: 'Open Settings',
                    onPressed: () => context.go(AppPaths.appSettings)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    final photoUrls = _orderedProfilePhotoUrls(_userJson);
    final img = photoUrls.isNotEmpty ? photoUrls.first : (g.imageUrl ?? '');
    final age = g.age != null ? ', ${g.age}' : '';
    final bio = (g.bio != null && g.bio!.trim().isNotEmpty)
        ? g.bio!
        : 'Add a short bio in Edit Profile.';
    final home = g.homeCourse ?? '—';
    final drink = _profileJson?['drinkingPreference'] as String? ?? '—';
    final smoke = _profileJson?['smokingPreference'] as String? ?? '—';
    final music = _profileJson?['musicPreference'] as String? ?? '—';

    return Scaffold(
      backgroundColor: CgColors.gray50,
      body: RefreshIndicator(
        color: CgColors.green700,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Builder(
                    builder: (context) {
                      final topPad = MediaQuery.paddingOf(context).top;
                      const greenContentH = 112.0;
                      return SizedBox(
                        height: topPad + greenContentH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      CgColors.green700,
                                      CgColors.green900
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: topPad + 4,
                              right: 8,
                              child: IconButton(
                                onPressed: () =>
                                    context.go(AppPaths.appSettings),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  foregroundColor: CgColors.white,
                                ),
                                icon: const Icon(Icons.settings_outlined),
                              ),
                            ),
                            Positioned(
                              left: 24,
                              right: 56,
                              top: topPad + 4,
                              bottom: 12,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      GestureDetector(
                                        onTap: photoUrls.isEmpty
                                            ? null
                                            : () => _showProfilePhotoGallery(
                                                context, photoUrls),
                                        child: Container(
                                          width: 88,
                                          height: 88,
                                          decoration: BoxDecoration(
                                            color: CgColors.gray200,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: CgColors.white,
                                                width: 3),
                                            boxShadow: const [
                                              BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 6)
                                            ],
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: img.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: img,
                                                  fit: BoxFit.cover)
                                              : const Center(
                                                  child: Icon(Icons.person,
                                                      size: 40,
                                                      color: CgColors.gray500),
                                                ),
                                        ),
                                      ),
                                      if (_verified)
                                        Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: const BoxDecoration(
                                              color: CgColors.blue600,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 4)
                                              ],
                                            ),
                                            child: const Icon(Icons.check,
                                                color: CgColors.white,
                                                size: 16),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Spacer(),
                                  OutlinedButton(
                                    onPressed: () =>
                                        context.push(AppPaths.appProfileEdit),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: CgColors.white,
                                      side: BorderSide(
                                          color: CgColors.white
                                              .withValues(alpha: 0.85)),
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.12),
                                    ),
                                    child: const Text('Edit Profile'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${g.displayName}$age',
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: CgColors.gray900,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.place_outlined,
                                          size: 18, color: CgColors.gray600),
                                      Expanded(
                                          child: Text(' ${g.cityLine}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (g.handicap != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                    color: CgColors.green600,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(_hcpLabel(),
                                    style: const TextStyle(
                                        color: CgColors.white,
                                        fontWeight: FontWeight.w500)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          bio,
                          style: textTheme.bodyLarge?.copyWith(
                            color: CgColors.gray700,
                            height: 1.45,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                                child: _miniStat('$_matchCount', 'Matches')),
                            const SizedBox(width: 12),
                            Expanded(child: _miniStat('—', 'Profile Views')),
                            const SizedBox(width: 12),
                            Expanded(child: _miniStat('—', 'Likes')),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _whiteCard(
                          title: 'Golf Information',
                          child: Column(
                            children: [
                              _KeyValueRow('Home Course', home),
                              const SizedBox(height: 12),
                              _KeyValueRow('Member Since', _memberSinceLabel()),
                              const SizedBox(height: 12),
                              _KeyValueRow('GHIN Status',
                                  _verified ? 'Verified' : 'Not verified',
                                  badge: _verified),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _whiteCard(
                          title: 'Playing Preferences',
                          child: Column(
                            children: [
                              _KeyValueRow(
                                  'Pace',
                                  _profileJson?['playFrequency'] as String? ??
                                      '—'),
                              const SizedBox(height: 12),
                              _KeyValueRow(
                                  'Competition',
                                  _profileJson?['skillLevel'] as String? ??
                                      '—'),
                              const SizedBox(height: 12),
                              _KeyValueRow('Drinking', drink),
                              const SizedBox(height: 12),
                              _KeyValueRow('Smoking', smoke),
                              const SizedBox(height: 12),
                              _KeyValueRow('Music', music),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_verified)
                          _gradientCard(
                            colors: const [
                              Color(0xFF2563EB),
                              Color(0xFF1D4ED8)
                            ],
                            title: 'Get GHIN Verified',
                            subtitle: 'Stand out with the blue badge',
                            icon: Icons.verified_user_outlined,
                            onTap: () => context.push(AppPaths.appVerification),
                          ),
                        if (!_premium) ...[
                          const SizedBox(height: 12),
                          _gradientCard(
                            colors: const [
                              CgColors.green700,
                              CgColors.green900
                            ],
                            title: 'Upgrade to Premium',
                            subtitle: 'Unlock all features',
                            icon: Icons.arrow_forward_ios,
                            onTap: () => context.push(AppPaths.appMembership),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Material(
                          color: CgColors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () =>
                                context.push(AppPaths.appNotifications),
                            child: const Padding(
                              padding: EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: CgColors.blue50,
                                    child: Icon(Icons.notifications_none,
                                        color: CgColors.blue600),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Notifications',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: CgColors.gray900,
                                        decoration: TextDecoration.none,
                                        inherit: false,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      color: CgColors.gray400),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _miniStat(String v, String l) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CgColors.gray200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Column(
        children: [
          Text(
            v,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: CgColors.gray900,
              decoration: TextDecoration.none,
              inherit: false,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l,
            style: const TextStyle(
              fontSize: 12,
              color: CgColors.gray600,
              decoration: TextDecoration.none,
              inherit: false,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _whiteCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CgColors.gray200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CgColors.gray900,
              decoration: TextDecoration.none,
              inherit: false,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  static Widget _gradientCard({
    required List<Color> colors,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(colors: colors),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: CgColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: CgColors.white.withValues(alpha: 0.9),
                            fontSize: 14)),
                  ],
                ),
              ),
              Icon(icon, color: CgColors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen swipe + pinch for own profile photos (tap avatar on Profile tab).
class _ProfilePhotoGalleryPage extends StatefulWidget {
  const _ProfilePhotoGalleryPage({required this.urls, this.initialIndex = 0});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_ProfilePhotoGalleryPage> createState() =>
      _ProfilePhotoGalleryPageState();
}

class _ProfilePhotoGalleryPageState extends State<_ProfilePhotoGalleryPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: urls[i],
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: CgColors.white),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: CgColors.gray400,
                      size: 56,
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.close_rounded,
                            color: CgColors.white, size: 26),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (urls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (i) {
                  final on = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: on ? 8 : 6,
                    height: on ? 8 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on
                          ? CgColors.white
                          : CgColors.white.withValues(alpha: 0.45),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow(this.k, this.v, {this.badge = false});

  final String k;
  final String v;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(
              fontSize: 14,
              color: CgColors.gray600,
              decoration: TextDecoration.none,
              inherit: false,
            ),
          ),
        ),
        if (badge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: CgColors.gray100,
                borderRadius: BorderRadius.circular(6)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 14, color: CgColors.gray700),
                SizedBox(width: 4),
                Text(
                  'Verified',
                  style: TextStyle(
                    fontSize: 12,
                    color: CgColors.gray900,
                    decoration: TextDecoration.none,
                    inherit: false,
                  ),
                ),
              ],
            ),
          )
        else
          Flexible(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 14,
                color: CgColors.gray900,
                decoration: TextDecoration.none,
                inherit: false,
              ),
              textAlign: TextAlign.right,
            ),
          ),
      ],
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _bio = TextEditingController();
  final _homeCourse = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _age = TextEditingController();
  final _handicap = TextEditingController();
  final _lookingFor = TextEditingController();
  final _drinking = TextEditingController();
  final _smoking = TextEditingController();
  final _music = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _bio.dispose();
    _homeCourse.dispose();
    _city.dispose();
    _state.dispose();
    _age.dispose();
    _handicap.dispose();
    _lookingFor.dispose();
    _drinking.dispose();
    _smoking.dispose();
    _music.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await ProfilesApi(session.apiClient).getMe(t);
      if (!mounted) return;
      _bio.text = j['bio'] as String? ?? '';
      _homeCourse.text = j['homeCourse'] as String? ?? '';
      _city.text = j['city'] as String? ?? '';
      _state.text = j['state'] as String? ?? '';
      final age = j['age'];
      _age.text = age == null ? '' : '$age';
      final h = j['handicap'];
      _handicap.text = h == null ? '' : h.toString();
      _lookingFor.text = j['lookingFor'] as String? ?? '';
      _drinking.text = j['drinkingPreference'] as String? ?? '';
      _smoking.text = j['smokingPreference'] as String? ?? '';
      _music.text = j['musicPreference'] as String? ?? '';
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = messageFromApiError(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final body = <String, dynamic>{};
    void put(String k, String v) {
      final t = v.trim();
      if (t.isNotEmpty) body[k] = t;
    }

    put('bio', _bio.text);
    put('homeCourse', _homeCourse.text);
    put('city', _city.text);
    put('state', _state.text);
    put('lookingFor', _lookingFor.text);
    put('drinkingPreference', _drinking.text);
    put('smokingPreference', _smoking.text);
    put('musicPreference', _music.text);
    final ageParsed = int.tryParse(_age.text.trim());
    if (ageParsed != null) body['age'] = ageParsed;
    final hParsed = double.tryParse(_handicap.text.trim());
    if (hParsed != null) body['handicap'] = hParsed;

    setState(() => _saving = true);
    try {
      await ProfilesApi(session.apiClient).updateMe(accessToken: t, body: body);
      if (!mounted) return;
      session.bumpProfileRefresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.gray50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Profile'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: CgColors.green700))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_error != null) ...[
                  Text(_error!,
                      style: const TextStyle(color: CgColors.destructive)),
                  const SizedBox(height: 16),
                ],
                CgLabeledField(
                    label: 'Bio',
                    child: CgTextField(
                        controller: _bio,
                        hint: 'Tell others about your golf game')),
                const SizedBox(height: 20),
                CgLabeledField(
                    label: 'Home course',
                    child: CgTextField(
                        controller: _homeCourse, hint: 'Your home course')),
                const SizedBox(height: 20),
                CgLabeledField(
                    label: 'City',
                    child: CgTextField(controller: _city, hint: 'City')),
                const SizedBox(height: 20),
                CgLabeledField(
                    label: 'State / region',
                    child: CgTextField(controller: _state, hint: 'CA')),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: CgLabeledField(
                        label: 'Age',
                        child: CgTextField(
                            controller: _age,
                            hint: '30',
                            keyboardType: TextInputType.number),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CgLabeledField(
                        label: 'Handicap',
                        child: CgTextField(
                            controller: _handicap,
                            hint: '12.5',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CgLabeledField(
                    label: 'Looking for',
                    child: CgTextField(
                        controller: _lookingFor,
                        hint: 'Playing partners, casual rounds…')),
                const SizedBox(height: 20),
                CgLabeledField(
                    label: 'Drinking preference',
                    child: CgTextField(
                        controller: _drinking, hint: 'Social, rarely…')),
                const SizedBox(height: 20),
                CgLabeledField(
                    label: 'Smoking preference',
                    child: CgTextField(
                        controller: _smoking, hint: 'No, outside only…')),
                const SizedBox(height: 20),
                CgLabeledField(
                    label: 'Music preference',
                    child: CgTextField(
                        controller: _music, hint: 'Quiet, cart speakers OK…')),
                const SizedBox(height: 24),
                CgPrimaryButton(
                  label: _saving ? 'Saving…' : 'Save changes',
                  onPressed: _saving ? null : _save,
                ),
                TextButton(
                  onPressed: () => context.push(AppPaths.appManagePhotos),
                  child: const Text('Manage photos'),
                ),
              ],
            ),
    );
  }
}

class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen(
      {super.key, required this.userId, this.distanceMilesHint});

  final String userId;
  final String? distanceMilesHint;

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  OtherUserProfileDetail? _detail;
  bool _loading = true;
  String? _error;
  late final PageController _photoController;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _photoController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await ProfilesApi(session.apiClient)
          .getPublic(accessToken: t, userId: widget.userId);
      final detail = OtherUserProfileDetail.fromPublicProfileJson(
        j,
        distanceMilesHint: widget.distanceMilesHint,
      );
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
          _error = detail == null ? 'Could not load profile' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageFromApiError(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _message() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null || _detail == null) return;
    try {
      final conv = await MessagesApi(session.apiClient)
          .startConversation(accessToken: t, otherUserId: _detail!.userId);
      final id = conv['id'] as String;
      if (mounted) {
        context.push(
            '${AppPaths.appMessages}/$id?peer=${Uri.encodeComponent(_detail!.userId)}');
      }
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    }
  }

  Future<void> _share() async {
    final d = _detail;
    if (d == null) return;
    await SharePlus.instance
        .share(ShareParams(text: '${d.displayName} — ConnectGHIN golfer'));
  }

  static String _memberSinceLabel(DateTime? d) {
    if (d == null) return '';
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _locationLine(OtherUserProfileDetail d) {
    final hint = d.distanceMilesHint?.trim();
    if (hint != null && hint.isNotEmpty) {
      return '$hint mi away  •  ${d.cityLine}';
    }
    return d.cityLine;
  }

  List<MapEntry<String, String>> _preferenceRows(OtherUserProfileDetail d) {
    final rows = <MapEntry<String, String>>[];
    void add(String label, String? v) {
      final t = v?.trim();
      if (t != null && t.isNotEmpty) rows.add(MapEntry(label, t));
    }

    add('Pace', d.playFrequency);
    add('Competition level', d.skillLevel);
    add('Drinking', d.drinkingPreference);
    add('Smoking', d.smokingPreference);
    add('Music', d.musicPreference);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: CgColors.white,
        body:
            Center(child: CircularProgressIndicator(color: CgColors.green700)),
      );
    }
    if (_error != null || _detail == null) {
      return Scaffold(
        backgroundColor: CgColors.gray50,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text('Profile'),
        ),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error ?? 'Not found'))),
      );
    }

    final d = _detail!;
    final photos = d.photoUrls.isNotEmpty ? d.photoUrls : <String>[];
    final headerHeight = MediaQuery.sizeOf(context).height * 0.44;
    final ageStr = d.age != null ? ', ${d.age}' : '';
    final hcpStr = d.handicap != null ? '${d.handicap} HCP' : null;
    final prefs = _preferenceRows(d);
    final myUserId = context.watch<AuthSession>().userId;
    final isOwnProfile = myUserId != null && myUserId == widget.userId;

    return Scaffold(
      backgroundColor: CgColors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: headerHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (photos.isEmpty)
                    const ColoredBox(
                      color: CgColors.gray200,
                      child: Center(
                          child: Icon(Icons.person,
                              size: 80, color: CgColors.gray400)),
                    )
                  else
                    PageView.builder(
                      controller: _photoController,
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _photoIndex = i),
                      itemBuilder: (context, i) {
                        return CachedNetworkImage(
                          imageUrl: photos[i],
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const ColoredBox(color: CgColors.gray200),
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: CgColors.gray200,
                            child: Icon(Icons.broken_image_outlined,
                                color: CgColors.gray400, size: 48),
                          ),
                        );
                      },
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 100,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55)
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _HeaderCircleBtn(
                              icon: Icons.arrow_back_ios_new,
                              size: 18,
                              onTap: () => context.pop()),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _HeaderCircleBtn(
                                  icon: Icons.share_rounded, onTap: _share),
                              if (d.verified) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: CgColors.blue600,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded,
                                          color: CgColors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'GHIN Verified',
                                        style: TextStyle(
                                          color: CgColors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (photos.length > 1) ...[
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: _HeaderCircleBtn(
                              icon: Icons.chevron_left_rounded,
                              size: 28,
                              onTap: () {
                                final next = _photoIndex > 0
                                    ? _photoIndex - 1
                                    : photos.length - 1;
                                _photoController.animateToPage(
                                  next,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _HeaderCircleBtn(
                              icon: Icons.chevron_right_rounded,
                              size: 28,
                              onTap: () {
                                final next = _photoIndex < photos.length - 1
                                    ? _photoIndex + 1
                                    : 0;
                                _photoController.animateToPage(
                                  next,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (photos.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(photos.length, (i) {
                          final on = i == _photoIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: on ? 8 : 6,
                            height: on ? 8 : 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: on
                                  ? CgColors.white
                                  : CgColors.white.withValues(alpha: 0.45),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          '${d.displayName}$ageStr',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: CgColors.gray900,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (hcpStr != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: CgColors.green700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            hcpStr,
                            style: const TextStyle(
                              color: CgColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_outlined,
                            size: 20, color: CgColors.gray500),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _locationLine(d),
                          style: const TextStyle(
                              fontSize: 15,
                              color: CgColors.gray600,
                              height: 1.35),
                        ),
                      ),
                    ],
                  ),
                  if ((d.bio ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('About',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      d.bio!.trim(),
                      style: const TextStyle(
                          fontSize: 15, color: CgColors.gray700, height: 1.45),
                    ),
                  ],
                  if ((d.homeCourse ?? '').trim().isNotEmpty ||
                      d.memberSince != null) ...[
                    const SizedBox(height: 28),
                    if ((d.homeCourse ?? '').trim().isNotEmpty)
                      _ProfileInfoRow(
                        icon: Icons.place_outlined,
                        label: 'Home Course',
                        value: d.homeCourse!.trim(),
                      ),
                    if ((d.homeCourse ?? '').trim().isNotEmpty &&
                        d.memberSince != null)
                      const SizedBox(height: 20),
                    if (d.memberSince != null)
                      _ProfileInfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Member Since',
                        value: _memberSinceLabel(d.memberSince),
                      ),
                  ],
                  if (d.lookingForTags.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text('Looking For',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: d.lookingForTags
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: CgColors.gray100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(t,
                                  style: const TextStyle(
                                      fontSize: 14, color: CgColors.gray900)),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (prefs.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text('Golf Preferences',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _PreferenceCard(rows: prefs),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _message,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CgColors.green700,
                        foregroundColor: CgColors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 22),
                      label: const Text('Send Message',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            '${AppPaths.appReportUser}?userId=${Uri.encodeComponent(widget.userId)}',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CgColors.gray900,
                            side: const BorderSide(color: CgColors.gray300),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.flag_outlined, size: 20),
                          label: const Text('Report',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            '${AppPaths.appBlockUser}?userId=${Uri.encodeComponent(widget.userId)}',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CgColors.gray900,
                            side: const BorderSide(color: CgColors.gray300),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.block_rounded, size: 20),
                          label: const Text('Block',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isOwnProfile)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          '${AppPaths.appPlayerRatings}?userId=${Uri.encodeComponent(widget.userId)}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CgColors.gray900,
                          side: const BorderSide(color: CgColors.gray300),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.star_outline_rounded, size: 20),
                        label: const Text('View Ratings',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(
                              '${AppPaths.appPlayerRatings}?userId=${Uri.encodeComponent(widget.userId)}',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: CgColors.gray900,
                              side: const BorderSide(color: CgColors.gray300),
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.star_outline_rounded, size: 20),
                            label: const Text('View Ratings',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(
                              '${AppPaths.appRatePlayer}?userId=${Uri.encodeComponent(widget.userId)}',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: CgColors.green700,
                              side: const BorderSide(color: CgColors.green700),
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.rate_review_outlined, size: 20),
                            label: const Text('Rate Player',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCircleBtn extends StatelessWidget {
  const _HeaderCircleBtn(
      {required this.icon, required this.onTap, this.size = 20});

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: CgColors.white, size: size),
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
              color: CgColors.green50, shape: BoxShape.circle),
          child: Icon(icon, color: CgColors.green700, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 13, color: CgColors.gray500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: CgColors.gray900)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CgColors.gray200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: CgColors.gray100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      rows[i].key,
                      style: const TextStyle(
                          fontSize: 14, color: CgColors.gray500),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CgColors.gray900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
