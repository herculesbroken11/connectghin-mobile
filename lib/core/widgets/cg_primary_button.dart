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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final double borderRadius;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final child = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: CgColors.green700,
        foregroundColor: CgColors.white,
        disabledBackgroundColor: CgColors.gray300,
        minimumSize: fullWidth ? Size(double.infinity, minHeight) : Size(0, minHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
    );
    return child;
  }
}
