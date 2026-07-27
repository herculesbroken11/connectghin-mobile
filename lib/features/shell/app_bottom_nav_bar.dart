import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// Shared bottom bar for [MainShell] and full-screen states that should still show tabs (e.g. offline).
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const labels = ['Home', 'Discover', 'Pair Up', 'Matches', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      color: CgColors.white,
      shadowColor: CgColors.charcoal.withValues(alpha: 0.18),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: CgColors.gray200.withValues(alpha: 0.9))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              5,
              (i) => _NavItem(
                index: i,
                selected: currentIndex == i,
                label: labels[i],
                isPairUp: i == 2,
                onTap: () => onDestinationSelected(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.selected,
    required this.label,
    required this.isPairUp,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final String label;
  final bool isPairUp;
  final VoidCallback onTap;

  Color get _icon => selected ? CgColors.green700 : CgColors.gray400;
  Color get _text => selected ? CgColors.green700 : CgColors.gray600;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPairUp)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [CgColors.fairway, CgColors.green900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: CgColors.green900.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: CgColors.premiumGold, width: 2),
                ),
                child: const Icon(Icons.sports_golf, color: CgColors.white, size: 26),
              )
            else
              Icon(_iconFor(index, selected), size: 24, color: _icon),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: _text,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (selected && !isPairUp) ...[
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: CgColors.premiumGold,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(int i, bool sel) {
    switch (i) {
      case 0:
        return sel ? Icons.home_rounded : Icons.home_outlined;
      case 1:
        return Icons.explore_outlined;
      case 3:
        return sel ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined;
      case 4:
        return sel ? Icons.settings : Icons.settings_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}
