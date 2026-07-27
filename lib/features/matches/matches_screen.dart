import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/formatting/relative_time.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_brand_header.dart';
import '../../core/widgets/cg_empty_state.dart';
import '../../core/widgets/cg_handicap_verified_badge.dart';
import '../../core/widgets/cg_premium_badge.dart';
import '../../core/widgets/cg_rating_chip.dart';
import '../../data/api_profile.dart';
import '../messages/data/inbox_realtime_tick.dart';
import '../messages/data/messages_api.dart';
import '../messages/widgets/inbox_avatar.dart';
import 'data/matches_api.dart';

class _MatchInboxRow {
  _MatchInboxRow({
    required this.card,
    required this.matchId,
    required this.matchedAt,
    this.conversationId,
    this.lastPreview,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final ApiGolferCard card;
  final String matchId;
  final DateTime matchedAt;
  final String? conversationId;
  final String? lastPreview;
  final DateTime? lastMessageAt;
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;

  String get previewLine {
    if (lastPreview != null && lastPreview!.trim().isNotEmpty) {
      final t = lastPreview!.trim();
      if (t.length > 72) return '${t.substring(0, 72)}…';
      return t;
    }
    return 'New match! Send a message to connect.';
  }

  String get timeLabel {
    final t = lastMessageAt ?? matchedAt;
    return formatRelativeTime(t);
  }

  String get locationLine {
    final course = card.homeCourse?.trim();
    if (course != null && course.isNotEmpty) return course;
    return card.cityLine;
  }

  bool matchesQuery(String q) {
    if (q.isEmpty) return true;
    final hay = [
      card.displayName,
      card.cityLine,
      card.homeCourse ?? '',
      lastPreview ?? '',
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }

  static _MatchInboxRow? tryParse(Map<String, dynamic> m, String viewerId) {
    final id = m['id'] as String?;
    final card = ApiGolferCard.fromMatch(m, viewerId);
    if (id == null || card == null) return null;
    final matchedAtRaw = m['matchedAt'];
    DateTime matchedAt;
    if (matchedAtRaw is String) {
      matchedAt = DateTime.tryParse(matchedAtRaw) ?? DateTime.now();
    } else {
      matchedAt = DateTime.now();
    }
    final chat = m['chatPreview'] as Map<String, dynamic>?;
    final convId = chat?['conversationId'] as String?;
    final preview = chat?['lastMessagePreview'] as String?;
    final lastAtStr = chat?['lastMessageAt'] as String?;
    final unread = chat?['unreadCount'];
    final unreadCount = unread is int ? unread : int.tryParse('$unread') ?? 0;
    return _MatchInboxRow(
      card: card,
      matchId: id,
      matchedAt: matchedAt,
      conversationId: convId,
      lastPreview: preview,
      lastMessageAt: tryParseIso(lastAtStr),
      unreadCount: unreadCount,
    );
  }
}

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  bool _loading = true;
  String? _error;
  List<_MatchInboxRow> _all = [];
  int _filterIndex = 0; // 0 All, 1 Unread
  String _query = '';
  final _search = TextEditingController();
  InboxRealtimeTick? _inboxTick;

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
    _search.dispose();
    super.dispose();
  }

  void _onInboxPing() {
    if (!mounted) return;
    unawaited(_load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    final uid = session.userId;
    if (t == null || uid == null) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final raw = await MatchesApi(session.apiClient).list(t);
      final rows = <_MatchInboxRow>[];
      for (final e in raw) {
        final row = _MatchInboxRow.tryParse(e as Map<String, dynamic>, uid);
        if (row != null) rows.add(row);
      }
      if (mounted) setState(() => _all = rows);
    } catch (e) {
      if (mounted && !silent) setState(() => _error = messageFromApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_MatchInboxRow> get _visible {
    final q = _query.trim().toLowerCase();
    Iterable<_MatchInboxRow> rows = _all;
    if (_filterIndex == 1) {
      rows = rows.where((r) => r.hasUnread);
    }
    if (q.isNotEmpty) {
      rows = rows.where((r) => r.matchesQuery(q));
    }
    return rows.toList();
  }

  int get _unreadTotal => _all.where((r) => r.hasUnread).length;

  Future<void> _confirmUnmatch(_MatchInboxRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unmatch?'),
        content: Text('Remove your match with ${r.card.displayName}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: CgColors.destructive),
            child: const Text('Unmatch'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    try {
      await MatchesApi(session.apiClient).unmatch(accessToken: t, matchId: r.matchId);
      if (mounted) {
        showUserMessageSnackBar(context, 'Match removed.');
        await _load();
      }
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    }
  }

  Future<void> _openRow(_MatchInboxRow r) async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final peer = r.card.userId;
    final matchedIso = Uri.encodeComponent(r.matchedAt.toIso8601String());
    try {
      if (r.conversationId != null && r.conversationId!.isNotEmpty) {
        if (!mounted) return;
        await context.push<String>(
          '${AppPaths.appMessages}/${r.conversationId}'
          '?peer=${Uri.encodeComponent(peer)}'
          '&name=${Uri.encodeComponent(r.card.displayName)}'
          '&matchedAt=$matchedIso',
        );
        if (mounted) await _load(silent: true);
        return;
      }
      final conv = await MessagesApi(session.apiClient).startConversation(accessToken: t, otherUserId: peer);
      final id = conv['id'] as String;
      if (mounted) {
        await context.push<String>(
          '${AppPaths.appMessages}/$id'
          '?peer=${Uri.encodeComponent(peer)}'
          '&name=${Uri.encodeComponent(r.card.displayName)}'
          '&matchedAt=$matchedIso',
        );
        if (mounted) await _load(silent: true);
      }
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _all.isEmpty) {
      return const ColoredBox(
        color: CgColors.cream,
        child: Center(child: CircularProgressIndicator(color: CgColors.green700)),
      );
    }
    if (_error != null && _all.isEmpty) {
      return ColoredBox(
        color: CgColors.cream,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final list = _visible;
    final total = _all.length;
    final unread = _unreadTotal;

    return ColoredBox(
      color: CgColors.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CgBrandHeader(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            bottomRadius: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Matches',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: CgColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? 'No golf connections yet'
                      : '$total golf connection${total == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: CgColors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: CgColors.white, fontSize: 15),
                  cursorColor: CgColors.premiumGoldLight,
                  decoration: InputDecoration(
                    hintText: 'Search matches...',
                    hintStyle: TextStyle(color: CgColors.white.withValues(alpha: 0.55)),
                    prefixIcon: Icon(Icons.search, color: CgColors.white.withValues(alpha: 0.7)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: Icon(Icons.close, color: CgColors.white.withValues(alpha: 0.7), size: 20),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                _MatchesTabs(
                  selectedIndex: _filterIndex,
                  unreadCount: unread,
                  onChanged: (i) => setState(() => _filterIndex = i),
                ),
              ],
            ),
          ),
          if (list.isEmpty && total == 0)
            Expanded(
              child: CgEmptyState(
                icon: const Icon(Icons.sports_golf, size: 44, color: CgColors.gray400),
                title: 'No matches yet',
                description: 'Start pairing up to connect with golfers in your area.',
                actionLabel: 'Pair Up',
                onAction: () => context.go(AppPaths.appGhinder),
              ),
            )
          else if (list.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _filterIndex == 1
                        ? 'No unread messages'
                        : (_query.isNotEmpty ? 'No matches match your search' : 'Nothing to show'),
                    style: const TextStyle(color: CgColors.gray600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: CgColors.green700,
                onRefresh: _load,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: CgColors.gray100),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return _MatchRow(
                      row: r,
                      onTap: () => _openRow(r),
                      onLongPress: () => _confirmUnmatch(r),
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

class _MatchesTabs extends StatelessWidget {
  const _MatchesTabs({
    required this.selectedIndex,
    required this.unreadCount,
    required this.onChanged,
  });

  final int selectedIndex;
  final int unreadCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabLabel(
          label: 'All',
          selected: selectedIndex == 0,
          onTap: () => onChanged(0),
        ),
        const SizedBox(width: 22),
        _TabLabel(
          label: unreadCount > 0 ? 'Unread ($unreadCount)' : 'Unread',
          selected: selectedIndex == 1,
          onTap: () => onChanged(1),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? CgColors.premiumGoldLight : CgColors.white.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 3,
              width: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: CgColors.premiumGold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.row,
    required this.onTap,
    required this.onLongPress,
  });

  final _MatchInboxRow row;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = row.card;
    final nameAge = c.age != null ? '${c.displayName} ${c.age}' : c.displayName;
    final hcp = c.handicap != null ? '${c.handicap} HCP' : null;
    final unread = row.hasUnread;

    return Material(
      color: CgColors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InboxAvatar(
                imageUrl: c.imageUrl,
                verified: c.verified,
                isPremium: c.isPremium,
                showUnreadDot: unread,
                radius: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            nameAge,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: CgColors.gray900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          row.timeLabel,
                          style: const TextStyle(fontSize: 12, color: CgColors.gray500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (c.isPremium) const CgPremiumBadge(compact: true),
                        if (c.verified)
                          const CgHandicapVerifiedBadge(compact: true, useShortLabel: true),
                        if (hcp != null) _MetaChip(label: hcp),
                        if (!c.rating.hasRating) const _MetaChip(label: 'New Player'),
                        CgRatingChip(
                          averageRating: c.rating.averageRating,
                          reviewCount: c.rating.reviewCount,
                          compact: true,
                        ),
                      ],
                    ),
                    if (row.locationLine.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 14, color: CgColors.gray500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              row.locationLine,
                              style: const TextStyle(fontSize: 12, color: CgColors.gray500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            row.previewLine,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              color: unread ? CgColors.gray900 : CgColors.gray600,
                              fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (row.unreadCount > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: CgColors.red500,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              row.unreadCount > 99 ? '99+' : '${row.unreadCount}',
                              style: const TextStyle(
                                color: CgColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CgColors.gray100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: CgColors.gray700,
        ),
      ),
    );
  }
}
