import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// Gold/amber premium badge with crown icon.
class CgPremiumBadge extends StatelessWidget {
  const CgPremiumBadge({
    super.key,
    this.compact = false,
    this.showLabel = true,
  });

  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 11.0 : 13.0;
    final fontSize = compact ? 10.0 : 11.0;
    final hPad = compact ? 6.0 : 8.0;
    final vPad = compact ? 3.0 : 5.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: CgColors.premiumGold,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: CgColors.premiumGold.withValues(alpha: 0.35),
            blurRadius: compact ? 0 : 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: iconSize, color: CgColors.white),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              'Premium',
              style: TextStyle(
                color: CgColors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular premium indicator for avatar overlays.
class CgPremiumAvatarBadge extends StatelessWidget {
  const CgPremiumAvatarBadge({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: CgColors.premiumGold,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      child: Icon(Icons.workspace_premium_rounded, size: size * 0.62, color: CgColors.white),
    );
  }
}
