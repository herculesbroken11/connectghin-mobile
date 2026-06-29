import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../core/widgets/cg_handicap_verified_badge.dart';
import '../../../core/widgets/cg_premium_badge.dart';

/// Circular avatar with optional unread dot, premium badge, and handicap verified badge.
class InboxAvatar extends StatelessWidget {
  const InboxAvatar({
    super.key,
    required this.imageUrl,
    required this.verified,
    this.isPremium = false,
    this.showUnreadDot = false,
    this.radius = 28,
  });

  final String? imageUrl;
  final bool verified;
  final bool isPremium;
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
          if (isPremium)
            Positioned(right: -2, bottom: -2, child: CgPremiumAvatarBadge(size: 18))
          else if (verified)
            Positioned(right: -2, bottom: -2, child: CgHandicapVerifiedAvatarBadge(size: 18)),
        ],
      ),
    );
  }
}
