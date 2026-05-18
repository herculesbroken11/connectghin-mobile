import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

class CgOutlineButton extends StatelessWidget {
  const CgOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: CgColors.gray900,
        side: const BorderSide(color: CgColors.gray300),
        minimumSize: fullWidth ? const Size(double.infinity, 48) : const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }
}
