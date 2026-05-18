import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

class CgLabeledField extends StatelessWidget {
  const CgLabeledField({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
  });

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: CgColors.gray900,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class CgTextField extends StatelessWidget {
  const CgTextField({
    super.key,
    this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 16, color: CgColors.gray900),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: CgColors.gray400),
        filled: true,
        fillColor: CgColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
