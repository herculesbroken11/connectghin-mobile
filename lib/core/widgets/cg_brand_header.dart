import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// Colored top band used across Connectghin screens.
class CgBrandHeader extends StatelessWidget {
  const CgBrandHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
    this.bottomRadius = 24,
    this.includeSafeTop = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double bottomRadius;
  final bool includeSafeTop;

  @override
  Widget build(BuildContext context) {
    final top = includeSafeTop ? MediaQuery.paddingOf(context).top : 0.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: CgColors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
        boxShadow: [
          BoxShadow(
            color: CgColors.green900.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: padding.copyWith(top: padding.top + top),
        child: child,
      ),
    );
  }
}

/// Soft cream preference / filter chip.
class CgPrefChip extends StatelessWidget {
  const CgPrefChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? CgColors.green700 : CgColors.white;
    final fg = selected ? CgColors.white : CgColors.gray700;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? CgColors.green700 : CgColors.gray200,
            ),
            boxShadow: selected ? null : CgShadows.soft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? CgColors.premiumGoldLight : CgColors.green700),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
