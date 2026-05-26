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

class CgTextField extends StatefulWidget {
  const CgTextField({
    super.key,
    this.controller,
    this.hint,
    this.obscure = false,
    this.showVisibilityToggle = false,
    this.keyboardType,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final bool showVisibilityToggle;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  State<CgTextField> createState() => _CgTextFieldState();
}

class _CgTextFieldState extends State<CgTextField> {
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscure;
  }

  @override
  void didUpdateWidget(covariant CgTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.obscure && oldWidget.obscure) {
      _obscured = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final useObscure = widget.obscure && (!widget.showVisibilityToggle || _obscured);
    return TextField(
      controller: widget.controller,
      obscureText: useObscure,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      style: const TextStyle(fontSize: 16, color: CgColors.gray900),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: CgColors.gray400),
        filled: true,
        fillColor: CgColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: widget.obscure && widget.showVisibilityToggle
            ? IconButton(
                tooltip: _obscured ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: CgColors.gray500,
                  size: 22,
                ),
              )
            : null,
      ),
    );
  }
}
