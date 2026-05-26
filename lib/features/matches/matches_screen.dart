import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/formatting/relative_time.dart';
import '../../core/network/api_user_message.dart';
import '../../data/api_profile.dart';
import '../../core/widgets/cg_empty_state.dart';
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
      if (t.length > 42) return '${t.substring(0, 42)}…';
      return t;
    }
    return 'New match! Start a conversation';
  }

  String get timeLabel {
    final t = lastMessageAt ?? matchedAt;
    return formatRelativeTime(t);
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await MatchesApi(session.apiClient).list(t);
      final rows = <_MatchInboxRow>[];
      for (final e in raw) {
        final row = _MatchInboxRow.tryParse(e as Map<String, dynamic>, uid);
        if (row != null) rows.add(row);
      }
      if (mounted) setState(() => _all = rows);
    } catch (e) {
      if (mounted) setState(() => _error = messageFromApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_MatchInboxRow> get _visible {
    if (_filterIndex == 1) {
      return _all.where((r) => r.hasUnread).toList();
    }
    return _all;
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
          '${AppPaths.appMessages}/${r.conversationId}?peer=${Uri.encodeComponent(peer)}&matchedAt=$matchedIso',
        );
        if (mounted) await _load();
        return;
      }
      final conv = await MessagesApi(session.apiClient).startConversation(accessToken: t, otherUserId: peer);
      final id = conv['id'] as String;
      if (mounted) {
        await context.push<String>(
          '${AppPaths.appMessages}/$id?peer=${Uri.encodeComponent(peer)}&matchedAt=$matchedIso',
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
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final list = _visible;
    final total = _all.length;

    return ColoredBox(
      color: CgColors.gray50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: CgColors.white,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Matches', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  total == 0 ? 'No connections yet' : '$total connection${total == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CgColors.gray600),
                ),
                if (total > 0) ...[
                  const SizedBox(height: 16),
                  _FilterPills(
                    allCount: total,
                    unreadCount: _unreadTotal,
                    selectedIndex: _filterIndex,
                    onChanged: (i) => setState(() => _filterIndex = i),
                  ),
                ],
              ],
            ),
          ),
          if (list.isEmpty && total == 0)
            Expanded(
              child: CgEmptyState(
                icon: const Icon(Icons.people_outline, size: 44, color: CgColors.gray400),
                title: 'No matches yet',
                description: 'Start swiping on GHINder to connect with golfers in your area. Your matches will appear here.',
                actionLabel: 'Start Swiping',
                onAction: () => context.go(AppPaths.appGhinder),
              ),
            )
          else if (list.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _filterIndex == 1 ? 'No unread messages' : 'Nothing to show',
                    style: const TextStyle(color: CgColors.gray600),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: CgColors.gray100),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    final c = r.card;
                    final title = c.age != null ? '${c.displayName}, ${c.age}' : c.displayName;
                    return Material(
                      color: CgColors.white,
                      child: InkWell(
                        onTap: () => _openRow(r),
                        onLongPress: () => _confirmUnmatch(r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              InboxAvatar(
                                imageUrl: c.imageUrl,
                                verified: c.verified,
                                showUnreadDot: r.hasUnread,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: CgColors.gray900),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          r.timeLabel,
                                          style: const TextStyle(fontSize: 12, color: CgColors.gray500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r.previewLine,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: r.lastPreview != null ? CgColors.gray600 : CgColors.green700,
                                        fontWeight: r.lastPreview != null ? FontWeight.normal : FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
            ),
        ],
      ),
    );
  }
}

class _FilterPills extends StatelessWidget {
  const _FilterPills({
    required this.allCount,
    required this.unreadCount,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int allCount;
  final int unreadCount;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CgColors.gray100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Pill(
              label: 'All ($allCount)',
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _Pill(
              label: 'Unread ($unreadCount)',
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? CgColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
              color: selected ? CgColors.gray900 : CgColors.gray600,
            ),
          ),
        ),
      ),
    );
  }
}
