import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../data/api_profile.dart';
import '../../core/widgets/cg_outline_button.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../discover/data/discover_api.dart';
import '../location/enable_location_screen.dart';
import '../location/location_profile.dart';
import '../messages/data/messages_api.dart';
import '../profiles/data/profiles_api.dart';
import '../swipes/data/swipes_api.dart';
import '../swipes/swipe_daily_quota.dart';
import '../../core/widgets/cg_brand_header.dart';
import '../../core/widgets/cg_handicap_verified_badge.dart';
import '../../core/widgets/cg_premium_badge.dart';
import '../../core/widgets/cg_rating_chip.dart';
import 'foursome_feed_tab.dart';

class GhinderScreen extends StatefulWidget {
  const GhinderScreen({super.key});

  @override
  State<GhinderScreen> createState() => _GhinderScreenState();
}

class _GhinderScreenState extends State<GhinderScreen> {
  List<ApiGolferCard> _profiles = [];
  int _index = 0;
  Offset _drag = Offset.zero;
  bool _loading = true;
  bool _missingLocation = false;
  String? _error;
  /// First profile photo URL from `GET /profiles/me` (viewer).
  String? _myPhotoUrl;
  double? _myHandicap;
  SwipeDailyQuota? _quota;
  int _tabIndex = 0;
  bool _isPremium = false;

  // Pair Up preference filters (aligned with Discover).
  double _filterDistance = 25; // 100 = Unlimited
  double _maxHandicap = 36; // 36 = Any
  String _smokePref = 'Any';
  String _friendly420 = 'Any';
  String _drinkPref = 'Any';
  String _musicPref = 'Any';
  String _playStyle = 'Any';
  String _availability = 'Any';

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
      _missingLocation = false;
      _index = 0;
    });
    try {
      final me = await ProfilesApi(session.apiClient).getMe(t);
      if (!LocationProfile.hasDiscoveryLocation(me)) {
        if (mounted) {
          setState(() {
            _missingLocation = true;
            _loading = false;
          });
        }
        return;
      }
      final raw = await DiscoverApi(session.apiClient).candidates(
        t,
        handicapMin: 0,
        handicapMax: _maxHandicap >= 36 ? null : _maxHandicap,
        maxDistanceMiles: _filterDistance >= 100 ? null : _filterDistance,
        skillLevel: _playStyle == 'Any' ? null : _playStyle,
        playFrequency: _availability == 'Any' ? null : _availability,
        musicPreference: _musicPref == 'Any' ? null : _musicPref,
        drinkingPreference: _drinkPref == 'Any' ? null : _drinkPref,
        smokingPreference: _smokePref == 'Any' ? null : _smokePref,
        friendly420: _friendly420 == 'Any' ? null : _friendly420,
      );
      final list = raw
          .map((e) => ApiGolferCard.fromDiscoveryProfile(e as Map<String, dynamic>))
          .whereType<ApiGolferCard>()
          .toList();
      SwipeDailyQuota? quota;
      try {
        quota = await SwipesApi(session.apiClient).fetchDailyQuota(t);
      } catch (_) {}
      final user = me['user'] as Map<String, dynamic>?;
      final photos = user?['profilePhotos'] as List<dynamic>?;
      String? myUrl;
      if (photos != null && photos.isNotEmpty) {
        myUrl = (photos.first as Map<String, dynamic>)['imageUrl'] as String?;
      }
      final h = me['handicap'];
      final myHcp = h is num ? h.toDouble() : double.tryParse('$h');
      final premium = user?['membershipType'] == 'PREMIUM' || (quota?.isPremium ?? false);
      if (mounted) {
        setState(() {
          _profiles = _applyFilters(list);
          _myPhotoUrl = myUrl;
          _myHandicap = myHcp;
          _quota = quota;
          _isPremium = premium;
          _loading = false;
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

  ApiGolferCard? get _current => _index < _profiles.length ? _profiles[_index] : null;

  void _showMatchDialog(ApiGolferCard peer) {
    final session = context.read<AuthSession>();
    final handicapLine = _matchHandicapLine(peer, _myHandicap);
    final locationLine = peer.cityLine.isNotEmpty && peer.cityLine != 'Nearby' ? peer.cityLine : 'Nearby';

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) {
        final size = MediaQuery.sizeOf(ctx);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _FallingGolfIconsLayer(height: size.height, width: size.width),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [CgColors.green600, CgColors.green800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24)],
                    ),
                    padding: const EdgeInsets.fromLTRB(0, 32, 0, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _RoundAvatar(url: _myPhotoUrl ?? ''),
                            Transform.translate(
                              offset: const Offset(-12, 0),
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: CgColors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
                                ),
                                child: const Icon(Icons.sports_golf, color: CgColors.green700, size: 32),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(-24, 0),
                              child: _RoundAvatar(url: peer.imageUrl ?? ''),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "It's a Match!",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: CgColors.white),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'You and ${peer.displayName} both swiped right',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: CgColors.white.withValues(alpha: 0.95)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.place_outlined, size: 18, color: CgColors.white.withValues(alpha: 0.9)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      locationLine,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14, color: CgColors.white.withValues(alpha: 0.9)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_outlined, size: 18, color: CgColors.white.withValues(alpha: 0.9)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      handicapLine,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14, color: CgColors.white.withValues(alpha: 0.9)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  final t = session.accessToken;
                                  if (t == null) return;
                                  try {
                                    final conv = await MessagesApi(session.apiClient).startConversation(
                                      accessToken: t,
                                      otherUserId: peer.userId,
                                    );
                                    final id = conv['id'] as String;
                                    if (!mounted) return;
                                    context.push(
                                      '${AppPaths.appMessages}/$id'
                                      '?peer=${Uri.encodeComponent(peer.userId)}'
                                      '&name=${Uri.encodeComponent(peer.displayName)}',
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    showApiErrorSnackBar(context, e);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: CgColors.white,
                                  foregroundColor: CgColors.green700,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Send a Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('Keep Swiping', style: TextStyle(color: CgColors.white.withValues(alpha: 0.9))),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _matchHandicapLine(ApiGolferCard peer, double? myHcp) {
    if (peer.handicap == null || myHcp == null) return 'Great match on the course';
    final d = (peer.handicap! - myHcp).abs();
    if (d <= 3) return 'Similar handicaps';
    if (d <= 8) return 'Compatible skill levels';
    return 'New playing partner';
  }

  /// One-way like: no mutual match yet — quick confirmation above the tab bar.
  void _showLikeSentFeedback() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.thumb_up_alt_rounded, color: CgColors.white, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Like sent — you'll match if they like you too",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        duration: const Duration(milliseconds: 2200),
        backgroundColor: CgColors.green700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _advance(ApiGolferCard profile, {required bool right}) async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    try {
      final res = await SwipesApi(session.apiClient).swipe(
        accessToken: t,
        toUserId: profile.userId,
        action: right ? 'LIKE' : 'PASS',
      );
      final matched = res['matched'] == true;
      SwipeDailyQuota? refreshed;
      try {
        refreshed = await SwipesApi(session.apiClient).fetchDailyQuota(t);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _drag = Offset.zero;
        if (refreshed != null) _quota = refreshed;
        if (_index < _profiles.length - 1) {
          _index++;
        } else {
          _index = _profiles.length;
        }
      });
      if (matched && mounted) {
        _showMatchDialog(profile);
      } else if (right && mounted) {
        _showLikeSentFeedback();
      }
    } catch (e) {
      final lim = tryParseDailySwipeLimit(e);
      if (lim != null) {
        if (mounted) await showDailySwipeLimitSheet(context, lim);
      } else if (mounted) {
        showApiErrorSnackBar(context, e);
      }
      if (mounted) setState(() => _drag = Offset.zero);
    }
  }

  void _swipeUi(bool right) {
    final p = _current;
    if (p == null) return;
    if (right) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() => _drag = Offset(right ? 300 : -300, 0));
    _advance(p, right: right);
  }

  String get _distanceLabel {
    if (_filterDistance >= 100) return 'Unlimited';
    return '${_filterDistance.round()} mi';
  }

  List<ApiGolferCard> _applyFilters(List<ApiGolferCard> source) {
    return source.where((g) {
      if (_filterDistance < 100 && g.distanceMiles != null && g.distanceMiles! > _filterDistance) {
        return false;
      }
      final h = g.handicap;
      if (h != null && _maxHandicap < 36 && h > _maxHandicap) {
        return false;
      }
      final chips = g.preferenceChips.map((e) => e.toLowerCase()).toList();
      final smoke = (g.smokingPreference ?? '').toLowerCase();
      final music = (g.musicPreference ?? '').toLowerCase();
      final drink = (g.drinkingPreference ?? '').toLowerCase();
      final skill = (g.skillLevel ?? '').toLowerCase();
      final avail = (g.playFrequency ?? '').toLowerCase();
      final bio = (g.bio ?? '').toLowerCase();

      if (_smokePref != 'Any') {
        if (_smokePref == 'No smoking') {
          if (smoke.isNotEmpty && !(smoke.contains('no') || smoke.contains('never'))) return false;
        } else if (_smokePref == 'OK') {
          if (smoke.isNotEmpty && (smoke.contains('no') || smoke.contains('never'))) return false;
        }
      }
      if (_friendly420 != 'Any') {
        final hit = chips.any((c) => c.contains('420') || c.contains('cannabis') || c.contains('weed')) ||
            smoke.contains('420') ||
            bio.contains('420');
        if (_friendly420 == 'Yes' && smoke.isNotEmpty && bio.isNotEmpty && !hit) return false;
        if (_friendly420 == 'No' && hit) return false;
      }
      if (_drinkPref != 'Any' && drink.isNotEmpty) {
        final want = _drinkPref.toLowerCase();
        if (!drink.contains(want) && !chips.any((c) => c.contains(want)) && !bio.contains(want)) {
          return false;
        }
      }
      if (_musicPref != 'Any' && music.isNotEmpty) {
        final want = _musicPref.toLowerCase();
        if (!music.contains(want) && !chips.any((c) => c.contains(want))) {
          if (want.contains('quiet') && !music.contains('quiet')) return false;
          if (want.contains('music') && music.contains('quiet')) return false;
        }
      }
      if (_playStyle != 'Any') {
        final want = _playStyle.toLowerCase();
        if (skill.isNotEmpty && !skill.contains(want) && !chips.any((c) => c.contains(want)) && !bio.contains(want)) {
          return false;
        }
      }
      if (_availability != 'Any') {
        final want = _availability.toLowerCase();
        if (avail.isNotEmpty && !avail.contains(want) && !chips.any((c) => c.contains(want)) && !bio.contains(want)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _openPairUpFilters() {
    var distance = _filterDistance;
    var maxHandicap = _maxHandicap;
    var smoke = _smokePref;
    var friendly420 = _friendly420;
    var drink = _drinkPref;
    var music = _musicPref;
    var playStyle = _playStyle;
    var availability = _availability;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CgColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModal) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: CgColors.gray300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Filter Golfers',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: CgColors.gray900,
                              ),
                            ),
                          ),
                          Material(
                            color: CgColors.gray100,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => Navigator.pop(ctx),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.close_rounded, color: CgColors.gray700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          _PairFilterSectionLabel(
                            label: 'DISTANCE',
                            value: distance >= 100 ? 'Unlimited' : '${distance.round()} mi',
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: CgColors.green700,
                              inactiveTrackColor: CgColors.gray200,
                              thumbColor: CgColors.green700,
                              overlayColor: CgColors.green700.withValues(alpha: 0.12),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: distance.clamp(5, 100),
                              min: 5,
                              max: 100,
                              divisions: 19,
                              onChanged: (v) => setModal(() => distance = v),
                            ),
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('5 mi', style: TextStyle(fontSize: 12, color: CgColors.gray500)),
                              Text('Unlimited', style: TextStyle(fontSize: 12, color: CgColors.gray500)),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _PairFilterSectionLabel(
                            label: 'MAX HANDICAP',
                            value: maxHandicap >= 36 ? 'Any' : maxHandicap.round().toString(),
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: CgColors.green700,
                              inactiveTrackColor: CgColors.gray200,
                              thumbColor: CgColors.green700,
                              overlayColor: CgColors.green700.withValues(alpha: 0.12),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: maxHandicap.clamp(1, 36),
                              min: 1,
                              max: 36,
                              divisions: 35,
                              onChanged: (v) => setModal(() => maxHandicap = v),
                            ),
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('1', style: TextStyle(fontSize: 12, color: CgColors.gray500)),
                              Text('Any (36+)', style: TextStyle(fontSize: 12, color: CgColors.gray500)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _PairFilterChipGroup(
                            label: 'STYLE OF PLAY',
                            options: const ['Any', 'Casual', 'Serious', 'Tournament'],
                            selected: playStyle,
                            onSelected: (v) => setModal(() => playStyle = v),
                          ),
                          _PairFilterChipGroup(
                            label: 'AVAILABILITY',
                            options: const ['Any', 'Weekdays', 'Weekends', 'Both'],
                            selected: availability,
                            onSelected: (v) => setModal(() => availability = v),
                          ),
                          _PairFilterChipGroup(
                            label: 'MUSIC ON THE COURSE',
                            options: const ['Any', 'Quiet rounds', 'Music OK'],
                            selected: music,
                            onSelected: (v) => setModal(() => music = v),
                          ),
                          _PairFilterChipGroup(
                            label: 'DRINKING',
                            options: const ['Any', 'No', 'Social', 'Yes'],
                            selected: drink,
                            onSelected: (v) => setModal(() => drink = v),
                          ),
                          _PairFilterChipGroup(
                            label: '420 FRIENDLY',
                            options: const ['Any', 'No', 'Yes'],
                            selected: friendly420,
                            onSelected: (v) => setModal(() => friendly420 = v),
                          ),
                          _PairFilterChipGroup(
                            label: 'SMOKING',
                            options: const ['Any', 'No smoking', 'OK'],
                            selected: smoke,
                            onSelected: (v) => setModal(() => smoke = v),
                          ),
                          const SizedBox(height: 8),
                          CgPrimaryButton(
                            label: 'Apply Filters',
                            onPressed: () {
                              setState(() {
                                _filterDistance = distance;
                                _maxHandicap = maxHandicap;
                                _smokePref = smoke;
                                _friendly420 = friendly420;
                                _drinkPref = drink;
                                _musicPref = music;
                                _playStyle = playStyle;
                                _availability = availability;
                              });
                              Navigator.pop(ctx);
                              _load();
                            },
                          ),
                          const SizedBox(height: 10),
                          CgOutlineButton(
                            label: 'Reset Filters',
                            onPressed: () {
                              setModal(() {
                                distance = 25;
                                maxHandicap = 36;
                                smoke = 'Any';
                                friendly420 = 'Any';
                                drink = 'Any';
                                music = 'Any';
                                playStyle = 'Any';
                                availability = 'Any';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: CgColors.gray50,
        child: Center(child: CircularProgressIndicator(color: CgColors.green700)),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: CgColors.gray50,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                CgPrimaryButton(label: 'Retry', onPressed: _load),
              ],
            ),
          ),
        ),
      );
    }
    if (_missingLocation) {
      return ColoredBox(
        color: CgColors.white,
        child: EnableLocationPanel(
          onSaved: _load,
          onSkipManual: () async {
            await context.push(AppPaths.appManualLocation);
            if (mounted) _load();
          },
        ),
      );
    }

    final current = _current;

    final ageStr = current?.age != null ? ', ${current!.age}' : '';
    final hcp = current?.handicap != null ? '${current!.handicap} HCP' : '';

    return ColoredBox(
      color: CgColors.cream,
      child: Column(
        children: [
          CgBrandHeader(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 16),
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
                            'Find Your 4th',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: CgColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tabIndex == 1
                                ? 'Golfers looking to fill their foursome nearby'
                                : 'Pair up with golfers near you',
                            style: TextStyle(
                              color: CgColors.premiumGoldLight.withValues(alpha: 0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_tabIndex == 0)
                      Material(
                        color: CgColors.charcoalSoft.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _openPairUpFilters,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune_rounded, size: 18, color: CgColors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Filters',
                                  style: TextStyle(
                                    color: CgColors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_tabIndex == 0 && _quota != null && !_quota!.isPremium && _quota!.dailyLimit != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 10),
                        child: Text(
                          '${_quota!.remaining} left',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CgColors.premiumGoldLight,
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.only(left: _tabIndex == 0 ? 6 : 0, top: 2),
                      child: Material(
                        color: _isPremium
                            ? CgColors.premiumGold.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => context.push(AppPaths.appMembership),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 16,
                                  color: CgColors.premiumGoldLight,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Premium',
                                  style: TextStyle(
                                    color: CgColors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _FindFourthTabBar(
                  index: _tabIndex,
                  onChanged: (i) => setState(() => _tabIndex = i),
                ),
                if (_tabIndex == 0 && current != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (_filterDistance < 100 ||
                          _maxHandicap < 36 ||
                          _playStyle != 'Any' ||
                          _availability != 'Any')
                        Expanded(
                          child: Text(
                            'Filtered · $_distanceLabel'
                            '${_playStyle != 'Any' ? ' · $_playStyle' : ''}',
                            style: TextStyle(
                              color: CgColors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const Spacer(),
                      Text(
                        '${_index + 1} / ${_profiles.length}',
                        style: TextStyle(
                          color: CgColors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_tabIndex == 1)
            const Expanded(child: FoursomeFeedTab())
          else if (current == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(color: CgColors.green50, shape: BoxShape.circle),
                        child: const Icon(Icons.sentiment_satisfied_alt, size: 48, color: CgColors.green600),
                      ),
                      const SizedBox(height: 24),
                      Text('No more profiles', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
                      const SizedBox(height: 8),
                      Text(
                        "You've seen everyone in your area for now. Try the Foursome Feed or check Discover.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      CgPrimaryButton(label: 'Refresh stack', onPressed: _load),
                      const SizedBox(height: 12),
                      CgOutlineButton(label: 'Go to Discover', onPressed: () => context.go(AppPaths.appDiscover)),
                    ],
                  ),
                ),
              ),
            )
          else
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardHeight = math.min(constraints.maxHeight - 8, 580.0);
                final course = current.homeCourse != null && current.homeCourse!.trim().isNotEmpty
                    ? current.homeCourse!.trim()
                    : current.cityLine;
                final distance = current.distanceMiles != null
                    ? '${current.distanceMiles!.toStringAsFixed(1)} mi'
                    : null;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) => setState(() => _drag += d.delta),
                    onHorizontalDragEnd: (d) {
                      final vx = d.velocity.pixelsPerSecond.dx;
                      final p = _current;
                      if (p == null) return;
                      if (_drag.dx < -80 || vx < -300) {
                        setState(() => _drag = const Offset(-300, 0));
                        _advance(p, right: false);
                      } else if (_drag.dx > 80 || vx > 300) {
                        setState(() => _drag = const Offset(300, 0));
                        _advance(p, right: true);
                      } else {
                        setState(() => _drag = Offset.zero);
                      }
                    },
                    child: Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: _drag,
                        child: Transform.rotate(
                          angle: _drag.dx * 0.001,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 420),
                            height: cardHeight,
                            decoration: BoxDecoration(
                              color: CgColors.charcoal,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: CgShadows.card,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (current.imageUrl != null && current.imageUrl!.isNotEmpty)
                                  CachedNetworkImage(imageUrl: current.imageUrl!, fit: BoxFit.cover)
                                else
                                  Container(
                                    color: CgColors.gray300,
                                    child: const Icon(Icons.person, size: 96, color: CgColors.gray500),
                                  ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x66000000),
                                        Color(0x14000000),
                                        Color(0xCC000000),
                                      ],
                                      stops: [0, 0.4, 1],
                                    ),
                                  ),
                                ),
                                if (_drag.dx.abs() > 24)
                                  Positioned(
                                    top: 28,
                                    left: _drag.dx > 0 ? 24 : null,
                                    right: _drag.dx < 0 ? 24 : null,
                                    child: Transform.rotate(
                                      angle: _drag.dx > 0 ? -0.2 : 0.2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: _drag.dx > 0 ? CgColors.green600 : CgColors.red500,
                                            width: 3,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _drag.dx > 0 ? 'LIKE' : 'PASS',
                                          style: TextStyle(
                                            color: _drag.dx > 0 ? CgColors.green600 : CgColors.red500,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 22,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 14,
                                  left: 14,
                                  right: 14,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            if (current.isPremium) const CgPremiumBadge(compact: true),
                                            if (current.verified)
                                              const CgHandicapVerifiedBadge(compact: true),
                                          ],
                                        ),
                                      ),
                                      if (hcp.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: CgColors.charcoal.withValues(alpha: 0.72),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            hcp,
                                            style: const TextStyle(
                                              color: CgColors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  left: 18,
                                  right: 18,
                                  bottom: 18,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${current.displayName}$ageStr',
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: CgColors.white,
                                          height: 1.15,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.place_outlined,
                                            size: 16,
                                            color: CgColors.white.withValues(alpha: 0.92),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              distance != null ? '$course · $distance' : course,
                                              style: TextStyle(
                                                color: CgColors.white.withValues(alpha: 0.92),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      CgRatingChip(
                                        averageRating: current.rating.averageRating,
                                        reviewCount: current.rating.reviewCount,
                                        compact: true,
                                      ),
                                      if (current.preferenceChips.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: current.preferenceChips
                                              .map(
                                                (c) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.18),
                                                    borderRadius: BorderRadius.circular(999),
                                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                                  ),
                                                  child: Text(
                                                    c,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: CgColors.white,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                      if (current.bio != null && current.bio!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          current.bio!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: CgColors.white.withValues(alpha: 0.88),
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_tabIndex == 0 && current != null)
          Container(
            color: CgColors.cream,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RejectCircleBtn(
                  onTap: () => _swipeUi(false),
                ),
                const SizedBox(width: 28),
                _CircleBtn(
                  size: 76,
                  borderColor: CgColors.green700,
                  fill: CgColors.green700,
                  child: const Icon(Icons.thumb_up_alt_rounded, size: 36, color: CgColors.white),
                  onTap: () => _swipeUi(true),
                ),
                const SizedBox(width: 28),
                _CircleBtn(
                  size: 56,
                  borderColor: CgColors.gray300,
                  fill: CgColors.white,
                  child: const Icon(Icons.info_outline, size: 26, color: CgColors.gray700),
                  onTap: () => context.push(
                    AppPaths.appProfileUser(current.userId),
                    extra: {
                      if (current.distanceMiles != null)
                        'distanceMilesHint': current.distanceMiles!.toStringAsFixed(1),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PairFilterSectionLabel extends StatelessWidget {
  const _PairFilterSectionLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: CgColors.gray500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: CgColors.green700,
          ),
        ),
      ],
    );
  }
}

class _PairFilterChipGroup extends StatelessWidget {
  const _PairFilterChipGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: CgColors.gray500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selected == option;
              return Material(
                color: isSelected ? CgColors.green700 : CgColors.gray100,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? CgColors.white : CgColors.gray700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FindFourthTabBar extends StatelessWidget {
  const _FindFourthTabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(label: 'Pair Up', selected: index == 0, onTap: () => onChanged(0)),
          ),
          Expanded(
            child: _TabChip(label: 'Foursome Feed', selected: index == 1, onTap: () => onChanged(1)),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? CgColors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? CgColors.green800 : CgColors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}

/// Golf-themed icons that fall from the top when a match modal opens.
class _FallingGolfIconsLayer extends StatefulWidget {
  const _FallingGolfIconsLayer({required this.height, required this.width});

  final double height;
  final double width;

  @override
  State<_FallingGolfIconsLayer> createState() => _FallingGolfIconsLayerState();
}

class _FallingGolfIconsLayerState extends State<_FallingGolfIconsLayer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final List<_FallParticle> _particles;
  final math.Random _rng = math.Random();

  static const _icons = [
    Icons.sports_golf,
    Icons.flag,
    Icons.thumb_up_alt_rounded,
    Icons.golf_course,
    Icons.park_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();
    _particles = List.generate(20, (i) {
      return _FallParticle(
        icon: _icons[i % _icons.length],
        xFrac: _rng.nextDouble() * 0.82 + 0.09,
        delay: i * 0.042,
        spin: (_rng.nextDouble() - 0.5) * 2.4,
        size: 20 + _rng.nextDouble() * 16,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _progress(_FallParticle p) {
    final g = _controller.value;
    if (g <= p.delay) return 0;
    return ((g - p.delay) / (1.0 - p.delay).clamp(0.2, 1.0)).clamp(0.0, 1.0);
  }

  Widget _particleWidget(_FallParticle p) {
    final t = _progress(p);
    if (t <= 0) return const SizedBox.shrink();
    final eased = Curves.easeIn.transform(t);
    final top = -36 + eased * (widget.height * 0.52);
    final left = p.xFrac * widget.width - p.size / 2;
    var o = 1.0;
    if (t < 0.08) {
      o = t / 0.08;
    }
    if (t > 0.88) {
      o = (1 - t) / 0.12;
    }
    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: o.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: p.spin * eased * math.pi,
          child: Icon(
            p.icon,
            size: p.size,
            color: Colors.white.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: _particles.map(_particleWidget).toList(),
          ),
        );
      },
    );
  }
}

class _FallParticle {
  _FallParticle({
    required this.icon,
    required this.xFrac,
    required this.delay,
    required this.spin,
    required this.size,
  });

  final IconData icon;
  final double xFrac;
  final double delay;
  final double spin;
  final double size;
}

class _RejectCircleBtn extends StatelessWidget {
  const _RejectCircleBtn({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CgColors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: CgColors.red500.withValues(alpha: 0.35),
      child: InkWell(
        customBorder: const CircleBorder(),
        splashColor: CgColors.red500.withValues(alpha: 0.28),
        highlightColor: CgColors.red500.withValues(alpha: 0.14),
        onTap: onTap,
        child: Ink(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: CgColors.red500, width: 2.5),
            color: CgColors.white,
          ),
          child: const Center(
            child: Icon(Icons.close, size: 32, color: CgColors.red500),
          ),
        ),
      ),
    );
  }
}

class _RoundAvatar extends StatelessWidget {
  const _RoundAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: CgColors.white, width: 4),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? ColoredBox(
              color: CgColors.gray300,
              child: Icon(Icons.person, size: 48, color: CgColors.gray500.withValues(alpha: 0.8)),
            )
          : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.size,
    required this.child,
    required this.onTap,
    required this.borderColor,
    this.fill,
  });

  final double size;
  final Widget child;
  final VoidCallback onTap;
  final Color borderColor;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill ?? CgColors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
            color: fill,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
