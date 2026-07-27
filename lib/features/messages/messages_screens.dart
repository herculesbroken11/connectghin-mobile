import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/config/api_config.dart';
import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/formatting/relative_time.dart';
import '../../core/network/api_user_message.dart';
import '../../data/api_profile.dart';
import '../../core/widgets/cg_empty_state.dart';
import 'data/chat_realtime.dart';
import 'data/messages_api.dart';
import '../profiles/data/profiles_api.dart';
import 'data/inbox_realtime_tick.dart';
import 'widgets/inbox_avatar.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  String? _error;
  List<_ConvRow> _all = [];
  int _filterIndex = 0;
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
    final myId = session.userId;
    if (t == null || myId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await MessagesApi(session.apiClient).listConversations(t);
      final rows = <_ConvRow>[];
      for (final e in raw) {
        final row = _ConvRow.tryParse(e as Map<String, dynamic>, myId);
        if (row != null) rows.add(row);
      }
      if (mounted) setState(() => _all = rows);
    } catch (e) {
      if (mounted) setState(() => _error = messageFromApiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_ConvRow> get _visible =>
      _filterIndex == 1 ? _all.where((r) => r.unreadCount > 0).toList() : _all;

  int get _unreadConversations => _all.where((r) => r.unreadCount > 0).length;

  @override
  Widget build(BuildContext context) {
    final subtitle = _error != null
        ? _error!
        : _all.isEmpty
            ? 'No conversations yet'
            : _unreadConversations > 0
                ? '$_unreadConversations unread conversation${_unreadConversations == 1 ? '' : 's'}'
                : '${_all.length} conversation${_all.length == 1 ? '' : 's'}';

    return Scaffold(
      backgroundColor: CgColors.gray50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: CgColors.white,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Messages', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _error != null ? CgColors.destructive : CgColors.gray600,
                        fontSize: _error != null ? 12 : null,
                      ),
                ),
                if (_all.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _MsgFilterPills(
                    allCount: _all.length,
                    unreadCount: _unreadConversations,
                    selectedIndex: _filterIndex,
                    onChanged: (i) => setState(() => _filterIndex = i),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: CgColors.green700))
                : _all.isEmpty
                    ? CgEmptyState(
                        icon: const Icon(Icons.chat_bubble_outline, size: 44, color: CgColors.gray400),
                        title: 'No messages yet',
                        description: 'Match with golfers to start conversations. Send a message to break the ice!',
                        actionLabel: 'Find Matches',
                        onAction: () => context.go(AppPaths.appGhinder),
                      )
                    : _visible.isEmpty
                        ? Center(
                            child: Text(
                              _filterIndex == 1 ? 'No unread threads' : 'Nothing to show',
                              style: const TextStyle(color: CgColors.gray600),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _visible.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: CgColors.gray100),
                              itemBuilder: (context, i) {
                                final c = _visible[i];
                                final title = c.other.age != null
                                    ? '${c.other.displayName}, ${c.other.age}'
                                    : c.other.displayName;
                                return Material(
                                  color: CgColors.white,
                                  child: InkWell(
                                    onTap: () async {
                                      await context.push<String>(
                                        '${AppPaths.appMessages}/${c.conversationId}'
                                        '?peer=${Uri.encodeComponent(c.other.userId)}'
                                        '&name=${Uri.encodeComponent(c.other.displayName)}',
                                      );
                                      if (mounted) await _load();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      child: Row(
                                        children: [
                                          InboxAvatar(
                                            imageUrl: c.other.imageUrl,
                                            verified: c.other.verified,
                                            showUnreadDot: c.unreadCount > 0,
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
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 16,
                                                          color: CgColors.gray900,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      c.timeLabel,
                                                      style: const TextStyle(fontSize: 12, color: CgColors.gray500),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  c.preview,
                                                  style: const TextStyle(fontSize: 14, color: CgColors.gray600),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (c.unreadCount > 0) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: CgColors.green700,
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${c.unreadCount > 9 ? '9+' : c.unreadCount}',
                                                style: const TextStyle(color: CgColors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 4),
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

class _MsgFilterPills extends StatelessWidget {
  const _MsgFilterPills({
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
      decoration: BoxDecoration(color: CgColors.gray100, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          Expanded(
            child: _MsgPill(
              label: 'All ($allCount)',
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _MsgPill(
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

class _MsgPill extends StatelessWidget {
  const _MsgPill({required this.label, required this.selected, required this.onTap});

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

class _ConvRow {
  _ConvRow({
    required this.conversationId,
    required this.other,
    required this.preview,
    required this.timeLabel,
    required this.unreadCount,
  });

  final String conversationId;
  final ApiGolferCard other;
  final String preview;
  final String timeLabel;
  final int unreadCount;

  static _ConvRow? tryParse(Map<String, dynamic> participantRow, String myUserId) {
    final unreadRaw = participantRow['unreadCount'];
    final unreadCount = unreadRaw is int ? unreadRaw : int.tryParse('$unreadRaw') ?? 0;

    final conv = participantRow['conversation'] as Map<String, dynamic>?;
    final row = conv ?? participantRow;
    final id = row['id'] as String? ?? row['conversationId'] as String?;
    if (id == null) return null;

    ApiGolferCard? other;
    final parts = row['participants'] as List<dynamic>?;
    if (parts != null) {
      Map<String, dynamic>? otherUserJson;
      for (final p in parts) {
        final m = p as Map<String, dynamic>;
        if ((m['userId'] as String?) != myUserId) {
          otherUserJson = m['user'] as Map<String, dynamic>?;
          break;
        }
      }
      if (otherUserJson != null) {
        other = ApiGolferCard.fromUserJson(otherUserJson);
      }
    }

    if (other == null) {
      final otherId = row['otherUserId'] as String?;
      if (otherId == null) return null;
      final otherName = row['otherDisplayName'] as String? ?? 'Golfer';
      final otherPhoto = row['otherPrimaryPhoto'] as String?;
      other = ApiGolferCard(
        userId: otherId,
        displayName: otherName,
        age: null,
        cityLine: 'Nearby',
        handicap: null,
        imageUrl: otherPhoto,
        verified: false,
      );
    }

    var preview = row['lastMessage'] as String? ?? 'Start chatting';
    var timeLabel = '';
    DateTime? sortTime;
    final msgs = row['messages'] as List<dynamic>?;
    if (msgs != null && msgs.isNotEmpty) {
      final last = msgs.first as Map<String, dynamic>;
      preview = last['body'] as String? ?? preview;
      if (preview.length > 48) preview = '${preview.substring(0, 48)}…';
      final created = last['createdAt'] as String?;
      if (created != null) {
        sortTime = DateTime.tryParse(created);
        if (sortTime != null) {
          timeLabel = formatRelativeTime(sortTime);
        }
      }
    }
    if (timeLabel.isEmpty) {
      final updated = row['updatedAt'] as String?;
      if (updated != null) {
        sortTime = DateTime.tryParse(updated);
        if (sortTime != null) {
          timeLabel = formatRelativeTime(sortTime);
        }
      }
    }

    return _ConvRow(
      conversationId: id,
      other: other,
      preview: preview,
      timeLabel: timeLabel.isEmpty ? '—' : timeLabel,
      unreadCount: unreadCount,
    );
  }
}

String _fmtIso(String iso) {
  try {
    return _fmtDt(DateTime.parse(iso).toLocal());
  } catch (_) {
    return '';
  }
}

String _fmtDt(DateTime l) {
  final h24 = l.hour;
  final am = h24 < 12;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h:${l.minute.toString().padLeft(2, '0')} ${am ? 'AM' : 'PM'}';
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    this.peerUserId,
    this.initialPeerName,
    this.matchedAtIso,
  });

  final String conversationId;
  final String? peerUserId;
  /// Passed from Matches / inbox so the header shows the real name immediately.
  final String? initialPeerName;
  /// From Matches flow — shows "You matched on …" banner when set.
  final String? matchedAtIso;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  bool _loading = true;
  String _titleName = 'Golfer';
  String? _resolvedPeerUserId;
  String? _titleAgeSuffix;
  String? _subtitleHcp;
  String? _avatarUrl;
  bool _peerVerified = false;
  final List<_Line> _lines = [];
  final Set<String> _messageIds = {};
  ChatRealtimeConnection? _realtime;

  String? get _peerId => widget.peerUserId ?? _resolvedPeerUserId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPeerName?.trim();
    if (initial != null && initial.isNotEmpty) {
      _titleName = initial;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _realtime?.disconnect();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    await _resolvePeerHeader(session, t);
    await _loadMessages();
    _startRealtime();
  }

  Future<void> _resolvePeerHeader(AuthSession session, String t) async {
    var peerId = widget.peerUserId;

    if (peerId == null || peerId.isEmpty) {
      try {
        final raw = await MessagesApi(session.apiClient).listConversations(t);
        final myId = session.userId;
        for (final row in raw) {
          if (row is! Map<String, dynamic>) continue;
          final parsed = _ConvRow.tryParse(row, myId ?? '');
          if (parsed == null) continue;
          if (parsed.conversationId != widget.conversationId) continue;
          peerId = parsed.other.userId;
          if (!mounted) return;
          setState(() {
            _resolvedPeerUserId = peerId;
            _applyPeerCard(parsed.other);
          });
          break;
        }
      } catch (_) {}
    }

    if (peerId == null || peerId.isEmpty) return;

    try {
      final prof = await ProfilesApi(session.apiClient).getPublic(accessToken: t, userId: peerId);
      final detail = OtherUserProfileDetail.fromPublicProfileJson(prof);
      final card = ApiGolferCard.fromAnyProfileJson(prof);
      if (!mounted) return;
      setState(() {
        _resolvedPeerUserId = peerId;
        if (detail != null) {
          _titleName = detail.displayName.trim().isNotEmpty ? detail.displayName : _titleName;
          _titleAgeSuffix = detail.age != null ? ', ${detail.age}' : null;
          _subtitleHcp = detail.handicap != null ? '${detail.handicap} HCP' : null;
          _avatarUrl = detail.photoUrls.isNotEmpty ? detail.photoUrls.first : _avatarUrl;
          _peerVerified = detail.verified;
        } else if (card != null) {
          _applyPeerCard(card);
        }
      });
    } catch (_) {}
  }

  void _applyPeerCard(ApiGolferCard card) {
    final name = card.displayName.trim();
    if (name.isNotEmpty) _titleName = name;
    _titleAgeSuffix = card.age != null ? ', ${card.age}' : null;
    _subtitleHcp = card.handicap != null ? '${card.handicap} HCP' : null;
    _avatarUrl = card.imageUrl;
    _peerVerified = card.verified;
  }

  void _startRealtime() {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    _realtime?.disconnect();
    _realtime = ChatRealtimeConnection(
      socketUrl: ApiConfig.socketChatUrl,
      accessToken: t,
      conversationId: widget.conversationId,
      onIncomingMessage: (payload) {
        if (!mounted) return;
        if (payload['conversationId'] != widget.conversationId) return;
        final myId = context.read<AuthSession>().userId;
        if (myId == null) return;
        setState(() => _appendMessageIfNew(payload, myId));
        _scrollBottom();
      },
      onMessagesRead: (payload) {
        if (!mounted) return;
        if (payload['conversationId'] != widget.conversationId) return;
        final readBy = payload['readByUserId'] as String?;
        final myId = context.read<AuthSession>().userId;
        if (readBy == null || myId == null || readBy == myId) return;
        unawaited(_syncMessagesFromServer());
      },
    );
    _realtime!.connect();
  }

  void _appendMessageIfNew(Map<String, dynamic> m, String myId) {
    final id = m['id'] as String?;
    if (id != null && _messageIds.contains(id)) {
      return;
    }
    if (id != null) {
      _messageIds.add(id);
    }
    final senderId = m['senderId'] as String?;
    final body = m['body'] as String? ?? '';
    final created = m['createdAt'];
    String label;
    if (created is String) {
      label = _fmtIso(created);
    } else if (created != null) {
      label = _fmtIso(created.toString());
    } else {
      label = _fmtDt(DateTime.now());
    }
    final peerRead = senderId == myId && m['isRead'] == true;
    _lines.add(_Line(body: body, mine: senderId == myId, timeLabel: label, peerRead: peerRead));
  }

  void _replaceLinesFromRaw(List<dynamic> raw, String myId) {
    final next = <_Line>[];
    final nextIds = <String>{};
    for (final e in raw) {
      final m = e as Map<String, dynamic>;
      final mid = m['id'] as String?;
      if (mid != null) {
        nextIds.add(mid);
      }
      final senderId = m['senderId'] as String?;
      final body = m['body'] as String? ?? '';
      final created = m['createdAt'] as String?;
      var label = '';
      if (created != null) {
        label = _fmtIso(created);
      }
      final peerRead = senderId == myId && m['isRead'] == true;
      next.add(_Line(body: body, mine: senderId == myId, timeLabel: label, peerRead: peerRead));
    }
    _messageIds
      ..clear()
      ..addAll(nextIds);
    _lines
      ..clear()
      ..addAll(next);
  }

  Future<void> _loadMessages() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    final myId = session.userId;
    if (t == null || myId == null) return;
    setState(() => _loading = true);
    try {
      final raw = await MessagesApi(session.apiClient).listMessages(accessToken: t, conversationId: widget.conversationId);
      if (mounted) {
        setState(() {
          _replaceLinesFromRaw(raw, myId);
          _loading = false;
        });
        _scrollBottom();
        unawaited(_markRead());
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncMessagesFromServer() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    final myId = session.userId;
    if (t == null || myId == null) return;
    try {
      final raw = await MessagesApi(session.apiClient).listMessages(accessToken: t, conversationId: widget.conversationId);
      if (mounted) {
        setState(() => _replaceLinesFromRaw(raw, myId));
      }
    } catch (_) {}
  }

  Future<void> _markRead() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    try {
      await MessagesApi(session.apiClient).markConversationRead(
        accessToken: t,
        conversationId: widget.conversationId,
      );
    } catch (_) {}
  }

  void _scrollBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  String? _matchBannerText() {
    final iso = widget.matchedAtIso;
    if (iso == null || iso.isEmpty) return null;
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = d.toLocal();
    final label = '${months[local.month - 1]} ${local.day}, ${local.year}';
    final name = _titleName;
    return 'You matched with $name on $label';
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    final myId = session.userId;
    if (t == null || myId == null) return;
    try {
      final res = await MessagesApi(session.apiClient).sendMessage(
        accessToken: t,
        conversationId: widget.conversationId,
        body: text,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() => _appendMessageIfNew(Map<String, dynamic>.from(res), myId));
      _scrollBottom();
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
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
        actions: [
          if (_peerId != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'profile') {
                  context.push(AppPaths.appProfileUser(_peerId!));
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'profile', child: Text('View profile')),
              ],
            ),
        ],
        title: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(_avatarUrl!)
                          : null,
                      child: _avatarUrl == null || _avatarUrl!.isEmpty
                          ? const Icon(Icons.person, size: 20)
                          : null,
                    ),
                  ),
                  if (_peerVerified)
                    const Positioned(
                      right: -4,
                      bottom: -4,
                      child: Icon(Icons.verified, size: 16, color: CgColors.blue600),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_titleName${_titleAgeSuffix ?? ''}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_subtitleHcp != null)
                    Text(_subtitleHcp!, style: const TextStyle(fontSize: 12, color: CgColors.gray500)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading && _lines.isEmpty
          ? const Center(child: CircularProgressIndicator(color: CgColors.green700))
          : Column(
              children: [
                if (_matchBannerText() != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    color: CgColors.green50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: CgColors.green100, shape: BoxShape.circle),
                          child: const Icon(Icons.favorite, color: CgColors.green700, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _matchBannerText()!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: CgColors.gray700, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _lines.length,
                    itemBuilder: (context, i) {
                      final m = _lines[i];
                      return Align(
                        alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                          decoration: BoxDecoration(
                            color: m.mine ? CgColors.green700 : CgColors.white,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: m.mine ? const Radius.circular(4) : null,
                              bottomLeft: m.mine ? null : const Radius.circular(4),
                            ),
                            boxShadow: m.mine ? null : const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                          ),
                          child: Column(
                            crossAxisAlignment: m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.body,
                                textAlign: m.mine ? TextAlign.right : TextAlign.left,
                                style: TextStyle(color: m.mine ? CgColors.white : CgColors.gray900),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    m.timeLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: m.mine ? CgColors.white.withValues(alpha: 0.8) : CgColors.gray500,
                                    ),
                                  ),
                                  if (m.mine && m.peerRead) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.done_all,
                                      size: 14,
                                      color: CgColors.white.withValues(alpha: 0.88),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  color: CgColors.white,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.paddingOf(context).bottom + 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _send,
                        style: IconButton.styleFrom(backgroundColor: CgColors.green700),
                        icon: const Icon(Icons.send, color: CgColors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Line {
  _Line({
    required this.body,
    required this.mine,
    required this.timeLabel,
    this.peerRead = false,
  });

  final String body;
  final bool mine;
  final String timeLabel;
  /// For outgoing bubbles: peer has read this message (server `isRead` after they mark the thread read).
  final bool peerRead;
}
