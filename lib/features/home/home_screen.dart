import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/google_mark.dart';
import '../../data/api_profile.dart';
import '../auth/widgets/auth_multi_login_widgets.dart';
import '../matches/data/matches_api.dart';
import '../messages/data/inbox_realtime_tick.dart';
import '../messages/data/messages_api.dart';
import '../profiles/data/profiles_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  int _matchCount = 0;
  int _convCount = 0;
  List<ApiGolferCard> _recent = [];
  /// From `GET /profiles/me` → `profileCompletionPercent` (see backend `computeProfileCompletionPercent`).
  int? _profileCompletionPercent;
  bool _isGhinVerified = false;
  InboxRealtimeTick? _inboxTick;
  String? _profileDisplayName;
  bool _expiredPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _inboxTick ??= context.read<InboxRealtimeTick>()..addListener(_onInboxPing);
  }

  @override
  void dispose() {
    _inboxTick?.removeListener(_onInboxPing);
    super.dispose();
  }

  void _onInboxPing() {
    if (!mounted) return;
    unawaited(_load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    final uid = session.userId;
    if (t == null || uid == null) return;
    try {
      final results = await Future.wait<Object>([
        MatchesApi(session.apiClient).list(t),
        MessagesApi(session.apiClient).listConversations(t),
        ProfilesApi(session.apiClient).getMe(t),
        session.authApi.me(t),
      ]);
      final matchesRaw = results[0] as List<dynamic>;
      final convRaw = results[1] as List<dynamic>;
      final profileJson = results[2] as Map<String, dynamic>;
      final authMe = results[3] as Map<String, dynamic>;
      final user = profileJson['user'];
      String? username;
      if (user is Map<String, dynamic>) {
        username = user['username'] as String?;
      }
      final displayName = profileJson['displayName'] as String? ?? username;
      final recent = <ApiGolferCard>[];
      for (final e in matchesRaw) {
        final card = ApiGolferCard.fromMatch(e as Map<String, dynamic>, uid);
        if (card != null) recent.add(card);
      }
      final pct = profileJson['profileCompletionPercent'];
      final verified = profileJson['isGHINVerified'] == true;
      if (mounted) {
        setState(() {
          _matchCount = matchesRaw.length;
          _convCount = convRaw.length;
          _recent = recent.take(3).toList();
          _profileCompletionPercent = pct is int ? pct : int.tryParse('$pct');
          _isGhinVerified = verified;
          _profileDisplayName = displayName;
          _loading = false;
        });
        final membershipStatus = authMe['membershipStatus']?.toString();
        final membershipType = authMe['membershipType']?.toString();
        if (!_expiredPromptShown &&
            membershipStatus == 'EXPIRED' &&
            membershipType == 'PREMIUM' &&
            mounted) {
          _expiredPromptShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.push(AppPaths.appSubscriptionExpired);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _profileCompletionPercent = null;
          _profileDisplayName = null;
        });
        showApiErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _openChat(ApiGolferCard g) async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    try {
      final conv = await MessagesApi(session.apiClient).startConversation(accessToken: t, otherUserId: g.userId);
      final id = conv['id'] as String;
      if (mounted) {
        await context.push<String>(
          '${AppPaths.appMessages}/$id?peer=${Uri.encodeComponent(g.userId)}',
        );
        if (mounted) await _load();
      }
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final firstName = _firstNameFromDisplay(_profileDisplayName);
    return ColoredBox(
      color: CgColors.gray50,
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: CgColors.white,
                  border: Border(bottom: BorderSide(color: CgColors.gray200)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CgAuthBrandMark(size: 44),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: CgColors.gray900,
                                      letterSpacing: -0.2,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _loading
                                    ? 'Loading your profile…'
                                    : 'Hi, $firstName — ready to connect with golfers?',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: CgColors.gray600,
                                      height: 1.35,
                                    ),
                              ),
                              if (session.lastSignInMethod != null) ...[
                                const SizedBox(height: 12),
                                _SignInMethodChip(method: session.lastSignInMethod!),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.push(AppPaths.appNotifications),
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.notifications_none_rounded, size: 26, color: CgColors.gray600),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: CgColors.red500, shape: BoxShape.circle),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'The premier golf network — discover verified partners, chat matches, and plan your next round.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: CgColors.gray500,
                            height: 1.4,
                            fontSize: 13,
                          ),
                    ),
                    if (session.lastSignInMethod == 'email') ...[
                      const SizedBox(height: 14),
                      Material(
                        color: CgColors.green50,
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        child: InkWell(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          onTap: () => context.push(AppPaths.appChangePassword),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.key_rounded, color: CgColors.green700, size: 22),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Signed in with email — update your password anytime in account security.',
                                    style: TextStyle(fontSize: 13, color: CgColors.gray700, height: 1.35),
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: CgColors.gray400),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: '$_matchCount',
                            label: 'Matches',
                            bg: CgColors.green50,
                            fg: CgColors.green700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            value: '$_convCount',
                            label: 'Conversations',
                            bg: CgColors.blue50,
                            fg: CgColors.blue700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: _StatCard(
                            value: '—',
                            label: 'Profile views',
                            bg: CgColors.purple50,
                            fg: CgColors.purple700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_profileCompletionPercent != null && _profileCompletionPercent! < 100)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CgColors.yellow50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CgColors.yellow200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Complete your profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: CgColors.yellow900)),
                              const SizedBox(height: 4),
                              Text(
                                !_isGhinVerified
                                    ? 'Add your GHIN number to get verified'
                                    : 'Finish photos and profile details to reach 100%',
                                style: const TextStyle(fontSize: 12, color: CgColors.yellow800),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: ((_profileCompletionPercent ?? 0).clamp(0, 100)) / 100.0,
                                  minHeight: 6,
                                  backgroundColor: CgColors.yellow100,
                                  color: CgColors.yellow500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_profileCompletionPercent!.clamp(0, 100)}% complete',
                                style: const TextStyle(fontSize: 12, color: CgColors.yellow700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => context.push(AppPaths.appCompleteProfile),
                          style: TextButton.styleFrom(
                            backgroundColor: CgColors.yellow600,
                            foregroundColor: CgColors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Complete'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Matches', style: Theme.of(context).textTheme.titleLarge),
                    TextButton(
                      onPressed: () => context.go(AppPaths.appMatches),
                      child: const Text('View all', style: TextStyle(color: CgColors.green700, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              sliver: SliverList.separated(
                itemCount: _recent.isEmpty ? 1 : _recent.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  if (_recent.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          _loading ? 'Loading…' : 'No matches yet — try GHINder!',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }
                  final m = _recent[i];
                  final img = m.imageUrl ?? '';
                  final ageStr = m.age != null ? '${m.age}' : '';
                  final hcp = m.handicap != null ? '${m.handicap} HCP' : '';
                  return Material(
                    color: CgColors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 1,
                    shadowColor: Colors.black12,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openChat(m),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            _Avatar(url: img, verified: m.verified),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.w500, color: CgColors.gray900)),
                                      if (ageStr.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Text(ageStr, style: const TextStyle(fontSize: 14, color: CgColors.gray500)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (hcp.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: CgColors.gray100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(hcp, style: const TextStyle(fontSize: 12, color: CgColors.gray700)),
                                        ),
                                      if (hcp.isNotEmpty) const SizedBox(width: 8),
                                      const Text('Open chat', style: TextStyle(fontSize: 12, color: CgColors.gray500)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: CgColors.gray400),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickTile(
                        icon: Icons.grid_view_rounded,
                        iconBg: CgColors.green100,
                        iconColor: CgColors.green700,
                        label: 'Start Swiping',
                        onTap: () => context.go(AppPaths.appGhinder),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickTile(
                        icon: Icons.search,
                        iconBg: CgColors.blue50,
                        iconColor: CgColors.blue700,
                        label: 'Browse Golfers',
                        onTap: () => context.go(AppPaths.appDiscover),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    gradient: LinearGradient(
                      colors: [CgColors.green700, CgColors.green900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Upgrade to Premium', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: CgColors.white)),
                      const SizedBox(height: 8),
                      Text(
                        'Message anyone directly, unlimited swipes, and more',
                        style: TextStyle(fontSize: 14, color: CgColors.white.withValues(alpha: 0.9)),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => context.push(AppPaths.appMembership),
                          style: TextButton.styleFrom(
                            backgroundColor: CgColors.white,
                            foregroundColor: CgColors.green700,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('See Premium Benefits', style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _firstNameFromDisplay(String? raw) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) return 'there';
    final parts = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'there';
    return parts.first;
  }
}

class _SignInMethodChip extends StatelessWidget {
  const _SignInMethodChip({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Widget icon;
    switch (method) {
      case 'google':
        label = 'Signed in with Google';
        icon = const GoogleMark(size: 15);
        break;
      case 'apple':
        label = 'Signed in with Apple';
        icon = const Icon(Icons.apple, size: 17, color: CgColors.gray900);
        break;
      default:
        label = 'Signed in with email';
        icon = const Icon(Icons.mail_outline, size: 17, color: CgColors.gray700);
        break;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CgColors.gray100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CgColors.gray300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CgColors.gray700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.bg, required this.fg});

  final String value;
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: fg)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: fg)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.verified});

  final String url;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: url.isNotEmpty
                ? CachedNetworkImage(imageUrl: url, width: 56, height: 56, fit: BoxFit.cover)
                : Container(width: 56, height: 56, color: CgColors.gray200, child: const Icon(Icons.person)),
          ),
          if (verified)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(color: CgColors.blue600, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 12, color: CgColors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CgColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CgColors.gray200),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 14, color: CgColors.gray900)),
            ],
          ),
        ),
      ),
    );
  }
}
