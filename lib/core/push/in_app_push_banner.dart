import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// Foreground push toast — card-style banner with sender + preview (not a plain text snackbar).
class InAppPushBanner {
  InAppPushBanner._();

  static void show(
    BuildContext context, {
    required RemoteMessage message,
    VoidCallback? onTap,
  }) {
    final title = _resolveTitle(message);
    final body = _resolveBody(message);
    if (title.isEmpty && body.isEmpty) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final style = _styleFor(message.data['type']);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 88),
        duration: const Duration(seconds: 5),
        content: Material(
          color: CgColors.white,
          elevation: 0,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              messenger.hideCurrentSnackBar();
              onTap?.call();
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: CgColors.gray200),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: style.iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(style.icon, size: 22, color: style.iconFg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          style.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CgColors.gray500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: CgColors.gray900,
                            height: 1.25,
                          ),
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: CgColors.gray600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 10),
                    child: Icon(Icons.chevron_right_rounded, color: CgColors.gray400, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _resolveTitle(RemoteMessage message) {
    final raw = message.notification?.title?.trim() ?? '';
    if (raw.isEmpty) return 'Connectghin';
    return _humanizeName(raw);
  }

  static String _resolveBody(RemoteMessage message) {
    return message.notification?.body?.trim() ?? '';
  }

  static String _humanizeName(String raw) {
    if (raw.contains(' ') || !raw.contains('_')) return raw;
    return raw
        .split('_')
        .where((p) => p.isNotEmpty)
        .map((p) => p.length == 1 ? p.toUpperCase() : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
        .join(' ');
  }

  static _BannerStyle _styleFor(String? type) {
    switch (type?.toUpperCase()) {
      case 'NEW_MESSAGE':
        return const _BannerStyle(
          label: 'New message',
          icon: Icons.chat_bubble_rounded,
          iconBg: CgColors.green50,
          iconFg: CgColors.green700,
        );
      case 'NEW_MATCH':
        return const _BannerStyle(
          label: 'New match',
          icon: Icons.thumb_up_alt_rounded,
          iconBg: Color(0xFFFCE7F3),
          iconFg: Color(0xFFDB2777),
        );
      default:
        return const _BannerStyle(
          label: 'Notification',
          icon: Icons.notifications_rounded,
          iconBg: CgColors.gray100,
          iconFg: CgColors.gray600,
        );
    }
  }
}

class _BannerStyle {
  const _BannerStyle({
    required this.label,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
  });

  final String label;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
}
