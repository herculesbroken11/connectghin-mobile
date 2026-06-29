import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// Player rating chip: star + average + review count, or "New Player".
class CgRatingChip extends StatelessWidget {
  const CgRatingChip({
    super.key,
    this.averageRating,
    this.reviewCount = 0,
    this.compact = false,
  });

  final double? averageRating;
  final int reviewCount;
  final bool compact;

  bool get _hasRating => averageRating != null && averageRating! > 0 && reviewCount > 0;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 11.0 : 12.0;
    final iconSize = compact ? 12.0 : 14.0;
    final hPad = compact ? 6.0 : 8.0;
    final vPad = compact ? 3.0 : 5.0;

    if (!_hasRating) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: CgColors.gray100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'New Player',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: CgColors.gray600,
          ),
        ),
      );
    }

    final avg = averageRating!.toStringAsFixed(1);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: CgColors.yellow100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CgColors.yellow200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: iconSize, color: CgColors.yellow600),
          const SizedBox(width: 3),
          Text(
            '$avg ($reviewCount)',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: CgColors.yellow800,
            ),
          ),
        ],
      ),
    );
  }
}
