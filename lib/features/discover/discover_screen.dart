import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_brand_header.dart';
import '../../core/widgets/cg_empty_state.dart';
import '../../core/widgets/cg_handicap_verified_badge.dart';
import '../../core/widgets/cg_outline_button.dart';
import '../../core/widgets/cg_premium_badge.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_rating_chip.dart';
import '../../data/api_profile.dart';
import '../location/enable_location_screen.dart';
import '../location/location_profile.dart';
import '../profiles/data/profiles_api.dart';
import '../swipes/data/swipes_api.dart';
import '../swipes/swipe_daily_quota.dart';
import 'data/discover_api.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  /// 100 = Unlimited
  double _distance = 25;
  /// 36 = Any
  double _maxHandicap = 36;
  bool _verifiedOnly = false;
  String _playStyle = 'Any';
  String _availability = 'Any';
  String _music = 'Any';
  String _drinking = 'Any';
  String _friendly420 = 'Any';
  String _smoking = 'Any';

  bool _loading = true;
  bool _missingLocation = false;
  String? _error;
  List<ApiGolferCard> _items = [];
  SwipeDailyQuota? _quota;

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
      final api = DiscoverApi(session.apiClient);
      final raw = await api.candidates(
        t,
        verifiedOnly: _verifiedOnly ? true : null,
        handicapMin: 0,
        handicapMax: _maxHandicap >= 36 ? null : _maxHandicap,
        maxDistanceMiles: _distance >= 100 ? null : _distance,
        skillLevel: _playStyle == 'Any' ? null : _playStyle,
        playFrequency: _availability == 'Any' ? null : _availability,
        musicPreference: _music == 'Any' ? null : _music,
        drinkingPreference: _drinking == 'Any' ? null : _drinking,
        smokingPreference: _smoking == 'Any' ? null : _smoking,
        friendly420: _friendly420 == 'Any' ? null : _friendly420,
      );
      final items = raw
          .map((e) => ApiGolferCard.fromDiscoveryProfile(e as Map<String, dynamic>))
          .whereType<ApiGolferCard>()
          .toList();
      SwipeDailyQuota? quota;
      try {
        quota = await SwipesApi(session.apiClient).fetchDailyQuota(t);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _items = items;
          _quota = quota;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageFromApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _like(ApiGolferCard g) async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    try {
      await SwipesApi(session.apiClient).swipe(accessToken: t, toUserId: g.userId, action: 'LIKE');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent like')));
        await _load();
      }
    } catch (e) {
      final lim = tryParseDailySwipeLimit(e);
      if (lim != null) {
        if (mounted) await showDailySwipeLimitSheet(context, lim);
      } else if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    }
  }

  void _resetFilters() {
    _distance = 25;
    _maxHandicap = 36;
    _verifiedOnly = false;
    _playStyle = 'Any';
    _availability = 'Any';
    _music = 'Any';
    _drinking = 'Any';
    _friendly420 = 'Any';
    _smoking = 'Any';
  }

  void _openFilters() {
    var distance = _distance;
    var maxHandicap = _maxHandicap;
    var verifiedOnly = _verifiedOnly;
    var playStyle = _playStyle;
    var availability = _availability;
    var music = _music;
    var drinking = _drinking;
    var friendly420 = _friendly420;
    var smoking = _smoking;

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
                          _FilterSectionLabel(
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
                              value: distance,
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
                          _FilterSectionLabel(
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
                          _FilterChipGroup(
                            label: 'STYLE OF PLAY',
                            options: const ['Any', 'Casual', 'Serious', 'Tournament'],
                            selected: playStyle,
                            onSelected: (v) => setModal(() => playStyle = v),
                          ),
                          _FilterChipGroup(
                            label: 'AVAILABILITY',
                            options: const ['Any', 'Weekdays', 'Weekends', 'Both'],
                            selected: availability,
                            onSelected: (v) => setModal(() => availability = v),
                          ),
                          _FilterChipGroup(
                            label: 'MUSIC ON THE COURSE',
                            options: const ['Any', 'Quiet rounds', 'Music OK'],
                            selected: music,
                            onSelected: (v) => setModal(() => music = v),
                          ),
                          _FilterChipGroup(
                            label: 'DRINKING',
                            options: const ['Any', 'No', 'Social', 'Yes'],
                            selected: drinking,
                            onSelected: (v) => setModal(() => drinking = v),
                          ),
                          _FilterChipGroup(
                            label: '420 FRIENDLY',
                            options: const ['Any', 'No', 'Yes'],
                            selected: friendly420,
                            onSelected: (v) => setModal(() => friendly420 = v),
                          ),
                          _FilterChipGroup(
                            label: 'SMOKING',
                            options: const ['Any', 'No smoking', 'OK'],
                            selected: smoking,
                            onSelected: (v) => setModal(() => smoking = v),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: CgColors.cream,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Handicap Verified only',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: CgColors.gray900,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Show only players with confirmed official handicap',
                                        style: TextStyle(fontSize: 12, color: CgColors.gray500, height: 1.35),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: verifiedOnly,
                                  activeTrackColor: CgColors.green700,
                                  onChanged: (v) => setModal(() => verifiedOnly = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          CgPrimaryButton(
                            label: 'Apply Filters',
                            onPressed: () {
                              setState(() {
                                _distance = distance;
                                _maxHandicap = maxHandicap;
                                _verifiedOnly = verifiedOnly;
                                _playStyle = playStyle;
                                _availability = availability;
                                _music = music;
                                _drinking = drinking;
                                _friendly420 = friendly420;
                                _smoking = smoking;
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
                                verifiedOnly = false;
                                playStyle = 'Any';
                                availability = 'Any';
                                music = 'Any';
                                drinking = 'Any';
                                friendly420 = 'Any';
                                smoking = 'Any';
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
    final list = _items;
    final countLabel = _loading
        ? 'Searching nearby…'
        : '${list.length} golfer${list.length == 1 ? '' : 's'} nearby';

    return ColoredBox(
      color: CgColors.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CgBrandHeader(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 18),
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
                            'Make a Foursome',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: CgColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _error ?? countLabel,
                            style: TextStyle(
                              color: _error != null
                                  ? CgColors.red400
                                  : CgColors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_quota != null &&
                              !_quota!.isPremium &&
                              _quota!.dailyLimit != null &&
                              !_loading) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${_quota!.remaining} likes left today',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CgColors.premiumGoldLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Material(
                      color: CgColors.charcoalSoft.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _openFilters,
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
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: List.generate(3, (_) => const _CardSkeleton()),
                  )
                : list.isEmpty
                    ? CgEmptyState(
                        icon: const Icon(Icons.search, size: 48, color: CgColors.gray400),
                        title: 'No golfers found',
                        description: 'Try adjusting your filters to see more results',
                        actionLabel: 'Reset Filters',
                        onAction: () {
                          setState(_resetFilters);
                          _load();
                        },
                      )
                    : RefreshIndicator(
                        color: CgColors.green700,
                        onRefresh: _load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final g = list[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _GolferCard(
                                golfer: g,
                                onView: () => context.push(
                                  AppPaths.appProfileUser(g.userId),
                                  extra: {
                                    if (g.distanceMiles != null)
                                      'distanceMilesHint': g.distanceMiles!.toStringAsFixed(1),
                                  },
                                ),
                                onLike: () => _like(g),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel({required this.label, required this.value});

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

class _FilterChipGroup extends StatelessWidget {
  const _FilterChipGroup({
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

class _GolferCard extends StatelessWidget {
  const _GolferCard({required this.golfer, required this.onView, required this.onLike});

  final ApiGolferCard golfer;
  final VoidCallback onView;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final ageStr = golfer.age != null ? ', ${golfer.age}' : '';
    final hcp = golfer.handicap != null ? '${golfer.handicap} HCP' : null;
    final img = golfer.imageUrl;
    final course = (golfer.homeCourse != null && golfer.homeCourse!.trim().isNotEmpty)
        ? golfer.homeCourse!.trim()
        : golfer.cityLine;
    final distance = golfer.distanceMiles != null ? '${golfer.distanceMiles!.toStringAsFixed(1)} mi' : null;

    return Container(
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: CgShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (img != null && img.isNotEmpty)
                  CachedNetworkImage(imageUrl: img, fit: BoxFit.cover)
                else
                  Container(
                    color: CgColors.gray200,
                    child: const Icon(Icons.person, size: 80, color: CgColors.gray400),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Color(0x00000000),
                        Color(0x99000000),
                      ],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (golfer.isPremium) const CgPremiumBadge(compact: true),
                            if (golfer.verified)
                              const CgHandicapVerifiedBadge(compact: true),
                          ],
                        ),
                      ),
                      if (hcp != null)
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
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${golfer.displayName}$ageStr',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: CgColors.white,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 16, color: CgColors.white.withValues(alpha: 0.92)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              distance != null ? '$course · $distance' : course,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: CgColors.white.withValues(alpha: 0.92),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CgRatingChip(
                      averageRating: golfer.rating.averageRating,
                      reviewCount: golfer.rating.reviewCount,
                      compact: true,
                    ),
                    const Spacer(),
                    Text(
                      golfer.cityLine,
                      style: const TextStyle(fontSize: 12, color: CgColors.gray500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (golfer.bio != null && golfer.bio!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    golfer.bio!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: CgColors.gray700, height: 1.4),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onView,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CgColors.green800,
                          backgroundColor: CgColors.cream,
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('View Profile', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onLike,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CgColors.green700,
                          foregroundColor: CgColors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: CgShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 300, color: CgColors.gray200),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  height: 14,
                  width: 160,
                  decoration: BoxDecoration(color: CgColors.gray200, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(color: CgColors.gray200, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(color: CgColors.gray100, borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(color: CgColors.gray200, borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
