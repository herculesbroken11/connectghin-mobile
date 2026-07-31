import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

class CgPrimaryButton extends StatelessWidget {
  const CgPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.fullWidth = true,
    this.borderRadius = 8,
    this.minHeight = 48,
    this.showTrailingArrow = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final double borderRadius;
  final double minHeight;
  final bool showTrailingArrow;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: CgColors.green700,
        foregroundColor: CgColors.white,
        disabledBackgroundColor: CgColors.gray300,
        minimumSize: fullWidth ? Size(double.infinity, minHeight) : Size(0, minHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      ),
      child: showTrailingArrow
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            )
          : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}
