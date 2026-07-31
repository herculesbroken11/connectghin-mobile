import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../core/widgets/cg_handicap_verified_badge.dart';
import '../../core/widgets/cg_premium_badge.dart';
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
    final distanceLabel =
        _filterDistance >= 100 ? 'Any distance' : 'Within ${_filterDistance.round()} miles';
    final filtersActive = _filterDistance != 25 ||
        _maxHandicap != 36 ||
        _smokePref != 'Any' ||
        _friendly420 != 'Any' ||
        _drinkPref != 'Any' ||
        _musicPref != 'Any' ||
        _playStyle != 'Any' ||
        _availability != 'Any';
    final likesLeft = _tabIndex == 0 &&
            _quota != null &&
            !_quota!.isPremium &&
            _quota!.dailyLimit != null
        ? _quota!.remaining
        : null;

    return ColoredBox(
      color: CgColors.cream,
      child: Column(
        children: [
          _PairUpHeader(
            likesLeft: likesLeft,
            filtersActive: filtersActive,
            isPremium: _isPremium,
            tabIndex: _tabIndex,
            onFilters: _openPairUpFilters,
            onPremium: () => context.push(AppPaths.appMembership),
            onTabChanged: (i) => setState(() => _tabIndex = i),
          ),
          if (_tabIndex == 1)
            const Expanded(child: FoursomeFeedTab())
          else if (current == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: CgColors.green50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.golf_course_rounded, size: 40, color: CgColors.green700),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'You’re all caught up',
                        style: GoogleFonts.fraunces(
                          color: CgColors.gray900,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No more golfers in range right now. Widen filters or check Discover.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: CgColors.gray500, fontSize: 14, height: 1.35),
                      ),
                      const SizedBox(height: 24),
                      CgPrimaryButton(label: 'Refresh', onPressed: _load),
                      const SizedBox(height: 12),
                      CgOutlineButton(
                        label: 'Open Discover',
                        onPressed: () => context.go(AppPaths.appDiscover),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: filtersActive ? CgColors.green700 : CgColors.gray500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            filtersActive ? 'Filtered · $distanceLabel' : distanceLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: filtersActive ? CgColors.green700 : CgColors.gray600,
                            ),
                          ),
                        ),
                        Text(
                          '${_index + 1} of ${_profiles.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CgColors.gray500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
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
                        child: Transform.translate(
                          offset: _drag,
                          child: Transform.rotate(
                            angle: _drag.dx * 0.0007,
                            child: _PairUpProfileCard(
                              golfer: current,
                              dragDx: _drag.dx,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabeledActionBtn(
                          size: 56,
                          label: 'Pass',
                          labelColor: CgColors.red500,
                          background: CgColors.white,
                          borderColor: CgColors.red500,
                          icon: Icons.close_rounded,
                          iconColor: CgColors.red500,
                          onTap: () => _swipeUi(false),
                        ),
                        const SizedBox(width: 22),
                        _LabeledActionBtn(
                          size: 68,
                          label: 'Pair Up',
                          labelColor: CgColors.green700,
                          background: CgColors.green700,
                          icon: Icons.thumb_up_alt_rounded,
                          iconColor: CgColors.white,
                          elevated: true,
                          onTap: () => _swipeUi(true),
                        ),
                        const SizedBox(width: 22),
                        _LabeledActionBtn(
                          size: 56,
                          label: 'Details',
                          labelColor: CgColors.gray600,
                          background: CgColors.white,
                          borderColor: CgColors.gray300,
                          icon: Icons.info_outline_rounded,
                          iconColor: CgColors.gray700,
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
                    const SizedBox(height: 4),
                  ],
                ),
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
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'Pair Up',
              icon: Icons.groups_rounded,
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _TabChip(
              label: 'Foursome Feed',
              icon: Icons.view_list_rounded,
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? CgColors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? CgColors.green800 : CgColors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? CgColors.green800 : CgColors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PairUpHeader extends StatelessWidget {
  const _PairUpHeader({
    required this.likesLeft,
    required this.filtersActive,
    required this.isPremium,
    required this.tabIndex,
    required this.onFilters,
    required this.onPremium,
    required this.onTabChanged,
  });

  final int? likesLeft;
  final bool filtersActive;
  final bool isPremium;
  final int tabIndex;
  final VoidCallback onFilters;
  final VoidCallback onPremium;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F3A28),
                    CgColors.green900,
                    CgColors.fairway,
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: CustomPaint(painter: _TopoPatternPainter()),
          ),
          // Decorative golf-course photo — right side only, fades into green.
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: MediaQuery.sizeOf(context).width * 0.58,
            child: IgnorePointer(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0x00000000),
                      Color(0x66000000),
                      Color(0xCC000000),
                      Color(0xFF000000),
                    ],
                    stops: [0.0, 0.28, 0.55, 1.0],
                  ).createShader(bounds);
                },
                child: Opacity(
                  opacity: 0.55,
                  child: Image.asset(
                    'assets/images/pair_up_header.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.35, 0.1),
                  ),
                ),
              ),
            ),
          ),
          // Soft vertical fade so the photo doesn't fight the tab bar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 56,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0F3A28).withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (tabIndex == 0)
                        _HeaderPillBtn(
                          label: 'Filters',
                          icon: Icons.tune_rounded,
                          outlined: true,
                          active: filtersActive,
                          onTap: onFilters,
                        )
                      else
                        const SizedBox(width: 1),
                      const Spacer(),
                      _HeaderPillBtn(
                        label: 'Premium',
                        icon: Icons.workspace_premium_rounded,
                        gold: true,
                        active: isPremium,
                        onTap: onPremium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find Your 4th',
                              style: GoogleFonts.fraunces(
                                color: CgColors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w600,
                                height: 1.05,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pair up with golfers near you',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: CgColors.premiumGoldLight.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (likesLeft != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.groups_outlined,
                                size: 16,
                                color: CgColors.premiumGoldLight.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$likesLeft players left',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CgColors.premiumGoldLight.withValues(alpha: 0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FindFourthTabBar(index: tabIndex, onChanged: onTabChanged),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopoPatternPainter extends CustomPainter {
  const _TopoPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    void contour(double cy, double amp, double freq) {
      final path = Path();
      path.moveTo(-8, cy);
      for (double x = -8; x <= size.width + 8; x += 8) {
        final y = cy + math.sin((x / size.width) * math.pi * freq) * amp;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    contour(size.height * 0.22, 10, 2.2);
    contour(size.height * 0.38, 14, 1.7);
    contour(size.height * 0.55, 11, 2.6);
    contour(size.height * 0.72, 16, 1.9);
    contour(size.height * 0.88, 9, 2.4);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeaderPillBtn extends StatelessWidget {
  const _HeaderPillBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
    this.gold = false,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;
  final bool gold;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = gold
        ? (active ? CgColors.premiumGold : CgColors.premiumGoldLight)
        : Colors.white.withValues(alpha: active ? 0.16 : 0.08);
    final fg = gold ? CgColors.green900 : CgColors.white;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: outlined
                ? Border.all(
                    color: active
                        ? CgColors.premiumGoldLight.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.35),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PairUpProfileCard extends StatelessWidget {
  const _PairUpProfileCard({required this.golfer, required this.dragDx});

  final ApiGolferCard golfer;
  final double dragDx;

  @override
  Widget build(BuildContext context) {
    final ageStr = golfer.age != null ? ', ${golfer.age}' : '';
    final hcp = golfer.handicap != null ? '${golfer.handicap} HCP' : null;
    final distance = golfer.distanceMiles != null
        ? '${golfer.distanceMiles!.toStringAsFixed(0)} mi away'
        : golfer.cityLine;
    final bio = (golfer.bio ?? '').trim();
    final chips = <_CardChipData>[];
    final isNew = !golfer.rating.hasRating;
    if (isNew) {
      chips.add(
        const _CardChipData(
          label: 'New Player',
          icon: Icons.star_rounded,
          filledMint: true,
        ),
      );
    }
    for (final c in golfer.preferenceChips.take(isNew ? 2 : 3)) {
      chips.add(_CardChipData(label: c, icon: _chipIconFor(c)));
    }
    if (hcp != null) {
      chips.add(_CardChipData(label: hcp, icon: Icons.sports_golf, filledGreen: true));
    }

    return Container(
      decoration: BoxDecoration(
        color: CgColors.charcoalSoft,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: CgColors.charcoal.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (golfer.imageUrl != null && golfer.imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: golfer.imageUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            )
          else
            const ColoredBox(
              color: CgColors.gray300,
              child: Center(child: Icon(Icons.person, size: 96, color: CgColors.gray500)),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xB3000000),
                  Color(0xE6000000),
                ],
                stops: [0.0, 0.2, 0.45, 0.72, 1.0],
              ),
            ),
          ),
          if (dragDx.abs() > 24)
            Positioned(
              top: 36,
              left: dragDx > 0 ? 22 : null,
              right: dragDx < 0 ? 22 : null,
              child: Transform.rotate(
                angle: dragDx > 0 ? -0.16 : 0.16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    border: Border.all(
                      color: dragDx > 0 ? CgColors.green600 : CgColors.red500,
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    dragDx > 0 ? 'PAIR' : 'PASS',
                    style: TextStyle(
                      color: dragDx > 0 ? CgColors.green600 : CgColors.red500,
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
              children: [
                if (golfer.isPremium) ...[
                  const CgPremiumBadge(compact: true),
                  const SizedBox(width: 6),
                ],
                if (golfer.verified) const CgHandicapVerifiedBadge(compact: true),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${golfer.displayName}$ageStr',
                    style: GoogleFonts.fraunces(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: CgColors.white,
                      height: 1.05,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 15, color: CgColors.white.withValues(alpha: 0.85)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          distance,
                          style: TextStyle(
                            color: CgColors.white.withValues(alpha: 0.9),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: chips.map((c) => _ProfileTagChip(data: c)).toList(),
                    ),
                  ],
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CgColors.white.withValues(alpha: 0.88),
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _chipIconFor(String label) {
    final t = label.toLowerCase();
    if (t.contains('month') || t.contains('week') || t.contains('day') || t.contains('rarely')) {
      return Icons.calendar_month_rounded;
    }
    if (t.contains('beginner') || t.contains('inter') || t.contains('advanced') || t.contains('pro')) {
      return Icons.bar_chart_rounded;
    }
    if (t.contains('sometimes') || t.contains('avail') || t.contains('weekend')) {
      return Icons.schedule_rounded;
    }
    if (t.contains('music') || t.contains('quiet')) return Icons.music_note_rounded;
    if (t.contains('smok')) return Icons.smoke_free;
    return Icons.sports_golf;
  }
}

class _CardChipData {
  const _CardChipData({
    required this.label,
    required this.icon,
    this.filledMint = false,
    this.filledGreen = false,
  });

  final String label;
  final IconData icon;
  final bool filledMint;
  final bool filledGreen;
}

class _ProfileTagChip extends StatelessWidget {
  const _ProfileTagChip({required this.data});

  final _CardChipData data;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Border? border;
    if (data.filledMint) {
      bg = const Color(0xFFD8F0E0);
      fg = CgColors.green800;
      border = null;
    } else if (data.filledGreen) {
      bg = CgColors.green700;
      fg = CgColors.white;
      border = null;
    } else {
      bg = Colors.white.withValues(alpha: 0.12);
      fg = CgColors.white;
      border = Border.all(color: Colors.white.withValues(alpha: 0.45));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            data.label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

class _LabeledActionBtn extends StatelessWidget {
  const _LabeledActionBtn({
    required this.size,
    required this.label,
    required this.labelColor,
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.borderColor,
    this.elevated = false,
  });

  final double size;
  final String label;
  final Color labelColor;
  final Color background;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: background,
          shape: const CircleBorder(),
          elevation: elevated ? 6 : 2,
          shadowColor: elevated
              ? CgColors.green700.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.12),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: borderColor == null ? null : Border.all(color: borderColor!, width: 2),
              ),
              child: Icon(icon, size: size * 0.4, color: iconColor),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
      ],
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


