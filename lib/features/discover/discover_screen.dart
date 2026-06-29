import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../data/api_profile.dart';
import '../../core/widgets/cg_empty_state.dart';
import '../../core/widgets/cg_handicap_verified_badge.dart';
import '../../core/widgets/cg_premium_badge.dart';
import '../../core/widgets/cg_rating_chip.dart';
import '../../core/widgets/cg_outline_button.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../discover/data/discover_api.dart';
import '../location/enable_location_screen.dart';
import '../location/location_profile.dart';
import '../profiles/data/profiles_api.dart';
import '../swipes/data/swipes_api.dart';
import '../swipes/swipe_daily_quota.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  double _distance = 25;
  RangeValues _handicap = const RangeValues(0, 36);
  bool _verifiedOnly = false;
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
        verifiedOnly: _verifiedOnly,
        handicapMin: _handicap.start,
        handicapMax: _handicap.end,
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

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CgColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Find golfers based on your preferences.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    Text('Distance: ${_distance.round()} miles (display only — server uses region)',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Slider(
                      value: _distance,
                      min: 1,
                      max: 50,
                      divisions: 49,
                      activeColor: CgColors.green700,
                      onChanged: (v) => setModal(() => _distance = v),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Handicap Range: ${_handicap.start.round()} - ${_handicap.end.round()}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    RangeSlider(
                      values: _handicap,
                      min: 0,
                      max: 36,
                      divisions: 72,
                      activeColor: CgColors.green700,
                      onChanged: (v) => setModal(() => _handicap = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Handicap verified only'),
                      value: _verifiedOnly,
                      activeThumbColor: CgColors.green700,
                      onChanged: (v) => setModal(() => _verifiedOnly = v),
                    ),
                    const SizedBox(height: 16),
                    CgPrimaryButton(
                      label: 'Apply Filters',
                      onPressed: () {
                        Navigator.pop(context);
                        _load();
                      },
                    ),
                    const SizedBox(height: 12),
                    CgOutlineButton(
                      label: 'Reset Filters',
                      onPressed: () {
                        setModal(() {
                          _distance = 25;
                          _handicap = const RangeValues(0, 36);
                          _verifiedOnly = false;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
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
    return ColoredBox(
      color: CgColors.gray50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: CgColors.white,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Discover', style: Theme.of(context).textTheme.headlineMedium),
                    OutlinedButton.icon(
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Filters'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CgColors.gray900,
                        side: const BorderSide(color: CgColors.gray300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: CgColors.destructive, fontSize: 12))
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loading ? 'Searching...' : '${list.length} golfers nearby',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_quota != null &&
                          !_quota!.isPremium &&
                          _quota!.dailyLimit != null &&
                          !_loading) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${_quota!.remaining} swipes left today',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CgColors.gray600,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: List.generate(3, (_) => const _CardSkeleton()),
                  )
                : list.isEmpty
                    ? CgEmptyState(
                        icon: const Icon(Icons.search, size: 48, color: CgColors.gray400),
                        title: 'No golfers found',
                        description: 'Try adjusting your filters to see more results',
                        actionLabel: 'Refresh',
                        onAction: _load,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: list.length + 1,
                          itemBuilder: (context, i) {
                            if (i == list.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: CgOutlineButton(label: 'Refresh', onPressed: _load),
                              );
                            }
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

class _GolferCard extends StatelessWidget {
  const _GolferCard({required this.golfer, required this.onView, required this.onLike});

  final ApiGolferCard golfer;
  final VoidCallback onView;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final ageStr = golfer.age != null ? ', ${golfer.age}' : '';
    final hcp = golfer.handicap != null ? '${golfer.handicap} HCP' : '— HCP';
    final img = golfer.imageUrl;
    return Container(
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 288,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (img != null && img.isNotEmpty)
                  CachedNetworkImage(imageUrl: img, fit: BoxFit.cover)
                else
                  Container(color: CgColors.gray200, child: const Icon(Icons.person, size: 80, color: CgColors.gray400)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                    ),
                  ),
                ),
                if (golfer.verified || golfer.isPremium)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        if (golfer.isPremium) const CgPremiumBadge(compact: true),
                        if (golfer.verified) const CgHandicapVerifiedBadge(compact: true, useShortLabel: true),
                        if (hcp != '— HCP')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(hcp, style: const TextStyle(color: CgColors.white, fontWeight: FontWeight.w600, fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${golfer.displayName}$ageStr',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: CgColors.white),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.place_outlined, size: 16, color: CgColors.white.withValues(alpha: 0.9)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    golfer.cityLine,
                                    style: TextStyle(fontSize: 14, color: CgColors.white.withValues(alpha: 0.9)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (hcp != '— HCP' && !golfer.verified && !golfer.isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: CgColors.green600, borderRadius: BorderRadius.circular(8)),
                          child: Text(hcp, style: const TextStyle(color: CgColors.white, fontWeight: FontWeight.w500)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
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
                      style: const TextStyle(fontSize: 12, color: CgColors.gray500),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(golfer.bio ?? '', style: const TextStyle(fontSize: 14, color: CgColors.gray700)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onView,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CgColors.gray900,
                          side: const BorderSide(color: CgColors.gray300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('View Profile'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onLike,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CgColors.green700,
                          foregroundColor: CgColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Connect'),
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
      decoration: BoxDecoration(color: CgColors.white, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 288, color: CgColors.gray200),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(height: 16, width: 200, decoration: BoxDecoration(color: CgColors.gray200, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(height: 12, width: 120, decoration: BoxDecoration(color: CgColors.gray200, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
