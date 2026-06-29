import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// Teal/green handicap verification badge. Replaces legacy "GHIN Verified" UI.
class CgHandicapVerifiedBadge extends StatelessWidget {
  const CgHandicapVerifiedBadge({
    super.key,
    this.compact = false,
    this.useShortLabel = false,
  });

  /// Smaller padding and font for card overlays.
  final bool compact;

  /// Use "HCP Verified" when space is tight.
  final bool useShortLabel;

  String get _label {
    if (useShortLabel) return 'HCP Verified';
    return compact ? 'HCP Verified' : 'Handicap Verified';
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 11.0 : 13.0;
    final fontSize = compact ? 10.0 : 11.0;
    final hPad = compact ? 6.0 : 8.0;
    final vPad = compact ? 3.0 : 5.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: CgColors.teal600,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, size: iconSize, color: CgColors.white),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              color: CgColors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small circular badge for avatar overlays.
class CgHandicapVerifiedAvatarBadge extends StatelessWidget {
  const CgHandicapVerifiedAvatarBadge({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: CgColors.teal600,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      child: Icon(Icons.verified_user_rounded, size: size * 0.62, color: CgColors.white),
    );
  }
}
