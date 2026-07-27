import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// UI placeholder for profile text/photo posts (course, group, landscape).
/// No backend posts API yet — safe display-only cards.
class CgProfilePostPlaceholder extends StatelessWidget {
  const CgProfilePostPlaceholder({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.photo_camera_outlined,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CgColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CgColors.gray200),
        boxShadow: CgShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CgColors.green100,
                  CgColors.premiumGold.withValues(alpha: 0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: CgColors.green700, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: CgColors.gray900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: CgColors.gray600),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: CgColors.gray400.withValues(alpha: 0.9), size: 20),
        ],
      ),
    );
  }
}
