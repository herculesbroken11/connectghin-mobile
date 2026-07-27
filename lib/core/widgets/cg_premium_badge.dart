import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// Gold premium badge with crown icon — high visibility.
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
    final iconSize = compact ? 13.0 : 16.0;
    final fontSize = compact ? 11.0 : 13.0;
    final hPad = compact ? 8.0 : 12.0;
    final vPad = compact ? 4.0 : 7.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CgColors.premiumGoldLight, CgColors.premiumGold, CgColors.premiumGoldDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CgColors.white.withValues(alpha: 0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: CgColors.premiumGold.withValues(alpha: 0.45),
            blurRadius: compact ? 6 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: iconSize, color: CgColors.white),
          if (showLabel) ...[
            const SizedBox(width: 5),
            Text(
              'Premium',
              style: TextStyle(
                color: CgColors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
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
