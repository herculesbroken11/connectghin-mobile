import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';

/// Circular avatar with optional unread dot (top-right) and GHIN verified badge (bottom-right).
class InboxAvatar extends StatelessWidget {
  const InboxAvatar({
    super.key,
    required this.imageUrl,
    required this.verified,
    this.showUnreadDot = false,
    this.radius = 28,
  });

  final String? imageUrl;
  final bool verified;
  final bool showUnreadDot;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasImg = imageUrl != null && imageUrl!.isNotEmpty;
    return SizedBox(
      width: radius * 2 + 4,
      height: radius * 2 + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            top: 2,
            child: CircleAvatar(
              radius: radius,
              backgroundColor: CgColors.gray200,
              backgroundImage: hasImg ? CachedNetworkImageProvider(imageUrl!) : null,
              child: hasImg ? null : Icon(Icons.person, size: radius, color: CgColors.gray500),
            ),
          ),
          if (showUnreadDot)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: CgColors.red500,
                  shape: BoxShape.circle,
                  border: Border.all(color: CgColors.white, width: 2),
                ),
              ),
            ),
          if (verified)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: CgColors.white, shape: BoxShape.circle),
                child: const Icon(Icons.verified, size: 16, color: CgColors.blue600),
              ),
            ),
        ],
      ),
    );
  }
}
