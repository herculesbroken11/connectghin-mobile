import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import 'app_bottom_nav_bar.dart';
import 'exit_app_confirm_dialog.dart';

/// Bottom navigation: Home, Discover, Find 4th, Matches, Settings.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ExitAppConfirmDialog.show(context);
      },
      child: Scaffold(
        backgroundColor: CgColors.white,
        body: navigationShell,
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) {
            navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            );
          },
        ),
      ),
    );
  }
}
