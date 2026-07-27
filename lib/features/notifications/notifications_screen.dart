import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import 'data/notifications_api.dart';

class _NotifStyle {
  const _NotifStyle({required this.bg, required this.fg, required this.icon});

  final Color bg;
  final Color fg;
  final IconData icon;
}

/// Inbox-style notifications (GHINder mock: unread tint, type icons, blue dot).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  static const _pinkBg = Color(0xFFFCE7F3);
  static const _pinkFg = Color(0xFFDB2777);
  static const _headingBlue = Color(0xFF001F3F);

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
      final raw = await NotificationsApi(session.apiClient).listNotifications(t);
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _markAllRead() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    try {
      await NotificationsApi(session.apiClient).markAllRead(t);
      if (!mounted) return;
      setState(() {
        _items = _items.map((m) => {...m, 'isRead': true}).toList();
      });
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _onTap(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    final read = row['isRead'] as bool? ?? true;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null || id == null) return;
    if (!read) {
      try {
        await NotificationsApi(session.apiClient).markRead(accessToken: t, notificationId: id);
        if (!mounted) return;
        setState(() {
          _items = _items.map((m) => m['id'] == id ? {...m, 'isRead': true} : m).toList();
        });
      } catch (_) {
        /* ignore */
      }
    }
    final data = row['dataJson'];
    if (data is Map<String, dynamic>) {
      final cid = data['conversationId'] as String?;
      if (cid != null && cid.isNotEmpty && mounted) {
        final peer = data['senderId'] as String? ?? data['peerUserId'] as String?;
        final name = data['senderName'] as String? ?? data['peerName'] as String?;
        final q = <String>[];
        if (peer != null && peer.isNotEmpty) q.add('peer=${Uri.encodeComponent(peer)}');
        if (name != null && name.isNotEmpty) q.add('name=${Uri.encodeComponent(name)}');
        final suffix = q.isEmpty ? '' : '?${q.join('&')}';
        context.push('${AppPaths.appMessages}/$cid$suffix');
        return;
      }
    }
    final deep = row['deepLink'] as String?;
    if (deep != null && deep.isNotEmpty && mounted) {
      context.push(deep);
      return;
    }
    final type = (row['type'] as String? ?? '').toUpperCase();
    if (!mounted) return;
    if (type.contains('MESSAGE')) {
      context.push(AppPaths.appMessages);
    } else if (type.contains('MATCH')) {
      context.go(AppPaths.appMatches);
    } else if (type.contains('LIKE')) {
      context.go(AppPaths.appDiscover);
    }
  }

  static _NotifStyle _styleFor(Map<String, dynamic> row) {
    final t = (row['type'] as String? ?? '').toUpperCase();
    final title = (row['title'] as String? ?? '').toLowerCase();

    if (t == 'NEW_MATCH') {
      return const _NotifStyle(bg: _pinkBg, fg: _pinkFg, icon: Icons.thumb_up_alt_outlined);
    }
    if (t == 'NEW_MESSAGE') {
      return const _NotifStyle(bg: CgColors.blue50, fg: CgColors.blue600, icon: Icons.chat_bubble_outline);
    }
    if (t.startsWith('GHIN_')) {
      return const _NotifStyle(bg: CgColors.purple50, fg: CgColors.purple700, icon: Icons.info_outline);
    }
    if (t.startsWith('SUBSCRIPTION_')) {
      return const _NotifStyle(bg: CgColors.green50, fg: CgColors.green700, icon: Icons.workspace_premium_outlined);
    }
    if (title.contains('like')) {
      return const _NotifStyle(bg: CgColors.green50, fg: CgColors.green700, icon: Icons.thumb_up_outlined);
    }
    return const _NotifStyle(bg: CgColors.gray100, fg: CgColors.gray600, icon: Icons.notifications_none_outlined);
  }

  static String _relTime(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inSeconds < 45) return 'Just now';
      if (diff.inMinutes < 60) {
        if (diff.inMinutes <= 1) return '1 minute ago';
        return '${diff.inMinutes} minutes ago';
      }
      if (diff.inHours < 24) {
        if (diff.inHours == 1) return '1 hour ago';
        return '${diff.inHours} hours ago';
      }
      if (diff.inDays == 1) return '1 day ago';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) {
        final w = diff.inDays ~/ 7;
        if (w == 1) return '1 week ago';
        return '$w weeks ago';
      }
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  int get _unreadCount => _items.where((m) => m['isRead'] != true).length;

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((m) => m['isRead'] != true);

    return Scaffold(
      backgroundColor: CgColors.gray50,
      appBar: AppBar(
        backgroundColor: CgColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: CgColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: const SizedBox.shrink(),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CgColors.green700,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CgColors.green700))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: _headingBlue,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _unreadCount == 0
                                ? 'No unread notifications'
                                : _unreadCount == 1
                                    ? '1 unread'
                                    : '$_unreadCount unread',
                            style: const TextStyle(fontSize: 15, color: CgColors.gray500, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _items.isEmpty
                          ? const Center(
                              child: Text(
                                'No notifications yet',
                                style: TextStyle(fontSize: 15, color: CgColors.gray600),
                              ),
                            )
                          : RefreshIndicator(
                              color: CgColors.green700,
                              onRefresh: _load,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: CgColors.gray200),
                                itemBuilder: (context, i) {
                                  final row = _items[i];
                                  final title = row['title'] as String? ?? 'Notification';
                                  final body = row['body'] as String? ?? '';
                                  final unread = row['isRead'] != true;
                                  final time = _relTime(row['createdAt'] as String?);
                                  final style = _styleFor(row);

                                  return Material(
                                    color: unread ? CgColors.blue50 : CgColors.white,
                                    child: InkWell(
                                      onTap: () => _onTap(row),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: style.bg,
                                              child: Icon(style.icon, color: style.fg, size: 24),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                                                      color: CgColors.gray900,
                                                      height: 1.25,
                                                    ),
                                                  ),
                                                  if (body.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      body,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        height: 1.4,
                                                        color: CgColors.gray600,
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    time,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: CgColors.gray400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (unread)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 6),
                                                child: Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: CgColors.blue600,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              )
                                            else
                                              const SizedBox(width: 8),
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
