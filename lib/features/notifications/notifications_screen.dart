import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_brand_header.dart';
import 'data/notifications_api.dart';

class _NotifStyle {
  const _NotifStyle({required this.bg, required this.fg, required this.icon});

  final Color bg;
  final Color fg;
  final IconData icon;
}

/// Inbox-style notifications with Connectghin green header + warm cream cards.
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
    return const _NotifStyle(bg: CgColors.creamDark, fg: CgColors.gray600, icon: Icons.notifications_none_outlined);
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

  String get _statusLabel {
    if (_unreadCount == 0) return 'No unread notifications';
    if (_unreadCount == 1) return '1 unread notification';
    return '$_unreadCount unread notifications';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _unreadCount > 0;

    return Scaffold(
      backgroundColor: CgColors.cream,
      body: Column(
        children: [
          CgBrandHeader(
            bottomRadius: 28,
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: CgColors.white),
                    ),
                    const Spacer(),
                    if (hasUnread)
                      TextButton(
                        onPressed: _markAllRead,
                        child: Text(
                          'Mark all read',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CgColors.premiumGoldLight.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 8, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.fraunces(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: CgColors.white,
                          height: 1.1,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stay updated with your golf activity',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: CgColors.white.withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 16,
                              color: hasUnread
                                  ? CgColors.premiumGoldLight
                                  : CgColors.white.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _statusLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: hasUnread
                                    ? CgColors.premiumGoldLight
                                    : CgColors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
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
                    : _items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: const BoxDecoration(
                                      color: CgColors.green50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.notifications_none_rounded,
                                      size: 34,
                                      color: CgColors.green700,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No notifications yet',
                                    style: GoogleFonts.fraunces(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: CgColors.gray900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Matches, messages, and golf updates will show up here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: CgColors.gray500, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: CgColors.green700,
                            backgroundColor: CgColors.white,
                            onRefresh: _load,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final row = _items[i];
                                final title = row['title'] as String? ?? 'Notification';
                                final body = row['body'] as String? ?? '';
                                final unread = row['isRead'] != true;
                                final time = _relTime(row['createdAt'] as String?);
                                final style = _styleFor(row);

                                return Material(
                                  color: CgColors.white,
                                  elevation: 0,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    onTap: () => _onTap(row),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: unread
                                              ? CgColors.green700.withValues(alpha: 0.22)
                                              : CgColors.gray200,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CgColors.charcoal.withValues(alpha: 0.05),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: style.bg,
                                            child: Icon(style.icon, color: style.fg, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        title,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                                                          color: CgColors.gray900,
                                                          height: 1.25,
                                                        ),
                                                      ),
                                                    ),
                                                    if (unread)
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        margin: const EdgeInsets.only(left: 6, top: 4),
                                                        decoration: const BoxDecoration(
                                                          color: CgColors.green700,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                  ],
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
                                                if (time.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.schedule_rounded,
                                                        size: 14,
                                                        color: CgColors.gray400,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        time,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: CgColors.gray400,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Padding(
                                            padding: EdgeInsets.only(top: 10),
                                            child: Icon(
                                              Icons.chevron_right_rounded,
                                              color: CgColors.gray300,
                                              size: 22,
                                            ),
                                          ),
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
