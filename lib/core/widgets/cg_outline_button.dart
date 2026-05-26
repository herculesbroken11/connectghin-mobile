import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

class CgOutlineButton extends StatelessWidget {
  const CgOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.fullWidth = true,
    this.borderColor,
    this.borderRadius = 8,
    this.minHeight = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final Color? borderColor;
  final double borderRadius;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: CgColors.gray900,
        backgroundColor: CgColors.white,
        side: BorderSide(color: borderColor ?? CgColors.gray300, width: 1.5),
        minimumSize: fullWidth ? Size(double.infinity, minHeight) : Size(0, minHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}
