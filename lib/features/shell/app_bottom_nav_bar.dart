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

  static const labels = ['Home', 'Discover', 'GHINder', 'Matches', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: CgColors.white,
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: CgColors.gray200)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              5,
              (i) => _NavItem(
                index: i,
                selected: currentIndex == i,
                label: labels[i],
                isGhinder: i == 2,
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
    required this.isGhinder,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final String label;
  final bool isGhinder;
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
            if (isGhinder)
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: CgColors.green700,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.grid_view_rounded, color: CgColors.white, size: 26),
              )
            else
              Icon(_iconFor(index, selected), size: 24, color: _icon),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: _text, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(int i, bool sel) {
    switch (i) {
      case 0:
        return sel ? Icons.home : Icons.home_outlined;
      case 1:
        return Icons.search;
      case 3:
        return sel ? Icons.favorite : Icons.favorite_border;
      case 4:
        return sel ? Icons.person : Icons.person_outline;
      default:
        return Icons.circle_outlined;
    }
  }
}
