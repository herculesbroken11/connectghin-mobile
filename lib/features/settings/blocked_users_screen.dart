import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../misc/data/account_api.dart';

/// Blocked users list (GHINder mock: cards, relative "Blocked … ago", unblock toast).
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  static const _headingBlue = Color(0xFF001F3F);

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _unblockToastName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final raw = await AccountApi(session.apiClient).listBlockedUsers(t);
      if (!mounted) return;
      setState(() {
        _rows = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _dismissToast() => setState(() => _unblockToastName = null);

  void _showUnblockToast(String name) {
    setState(() => _unblockToastName = name);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _unblockToastName == name) {
        setState(() => _unblockToastName = null);
      }
    });
  }

  Future<void> _unblock(Map<String, dynamic> row) async {
    final blockedUserId = row['blockedUserId'] as String? ?? '';
    if (blockedUserId.isEmpty) return;
    final displayName = row['displayName'] as String? ??
        row['username'] as String? ??
        (row['blockedUserId'] as String?) ??
        'User';
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    try {
      await AccountApi(session.apiClient).unblockUser(accessToken: t, blockedUserId: blockedUserId);
      if (!mounted) return;
      setState(() => _rows = _rows.where((r) => r['blockedUserId'] != blockedUserId).toList());
      _showUnblockToast(displayName);
    } catch (e) {
      if (!mounted) return;
      showApiErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _rows.length;
    final subtitle = n == 0
        ? 'No users blocked'
        : n == 1
            ? '1 user blocked'
            : '$n users blocked';

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
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_unblockToastName != null)
            Material(
              color: CgColors.green50,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: CgColors.green600, width: 1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: CgColors.green700, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$_unblockToastName has been unblocked.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CgColors.green800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: CgColors.gray500),
                      onPressed: _dismissToast,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: CgColors.green700))
                : RefreshIndicator(
                    color: CgColors.green700,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      children: [
                        const Text(
                          'Blocked Users',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: BlockedUsersScreen._headingBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 15,
                            color: CgColors.blue700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 48),
                            child: Text(
                              'People you block will appear here. They cannot see your profile, message you, or match with you.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray600),
                            ),
                          )
                        else
                          ..._rows.map((row) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _BlockedUserCard(row: row, onUnblock: () => _unblock(row)),
                              )),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: CgColors.blue50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(fontSize: 14, height: 1.45, color: CgColors.blue700),
                              children: [
                                TextSpan(
                                  text: 'About blocking: ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text:
                                      'Blocked users cannot see your profile, send you messages, or match with you. '
                                      "They won't be notified that you've blocked them.",
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BlockedUserCard extends StatelessWidget {
  const _BlockedUserCard({required this.row, required this.onUnblock});

  final Map<String, dynamic> row;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final name = row['displayName'] as String? ??
        row['username'] as String? ??
        (row['blockedUserId'] as String?) ??
        'User';
    final photoUrl = row['photoUrl'] as String?;
    final when = _formatBlockedAgo(row['createdAt']);

    return Container(
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
          children: [
            ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 52,
                        height: 52,
                        color: CgColors.gray100,
                        child: const Icon(Icons.person, color: CgColors.gray400),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: CgColors.gray100,
                        child: const Icon(Icons.person, color: CgColors.gray400),
                      ),
                    )
                  : Container(
                      width: 52,
                      height: 52,
                      color: CgColors.gray100,
                      child: const Icon(Icons.person, size: 28, color: CgColors.gray400),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: BlockedUsersScreen._headingBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    when,
                    style: const TextStyle(fontSize: 14, color: CgColors.blue600, height: 1.2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onUnblock,
              style: OutlinedButton.styleFrom(
                foregroundColor: CgColors.gray900,
                side: const BorderSide(color: CgColors.gray300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: const Text('Unblock'),
            ),
          ],
        ),
    );
  }
}

String _formatBlockedAgo(dynamic createdAt) {
  if (createdAt == null) return 'Blocked';
  DateTime d;
  try {
    d = DateTime.parse(createdAt.toString()).toLocal();
  } catch (_) {
    return 'Blocked';
  }
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Blocked just now';
  if (diff.inHours < 1) return 'Blocked ${diff.inMinutes} minutes ago';
  if (diff.inHours < 24) {
    if (diff.inHours == 1) return 'Blocked 1 hour ago';
    return 'Blocked ${diff.inHours} hours ago';
  }
  if (diff.inDays == 1) return 'Blocked 1 day ago';
  if (diff.inDays < 7) return 'Blocked ${diff.inDays} days ago';
  final weeks = diff.inDays ~/ 7;
  if (weeks == 1) return 'Blocked 1 week ago';
  if (weeks < 5) return 'Blocked $weeks weeks ago';
  return 'Blocked on ${d.month}/${d.day}/${d.year}';
}
