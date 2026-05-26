import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';
import '../shell/app_bottom_nav_bar.dart';

/// Full-screen offline state (GHINder mock: tips card + tab bar still visible).
class NoConnectionScreen extends StatelessWidget {
  const NoConnectionScreen({super.key});

  static const _headingBlue = Color(0xFF001F3F);

  static const _tabPaths = <String>[
    AppPaths.app,
    AppPaths.appDiscover,
    AppPaths.appGhinder,
    AppPaths.appMatches,
    AppPaths.appSettings,
  ];

  void _tryAgain(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppPaths.app);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.white,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: CgResponsiveContainer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      color: CgColors.gray100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_off_rounded, size: 44, color: CgColors.gray600),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'No Internet Connection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _headingBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please check your connection and try again',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray600),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: CgColors.blue50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tips to reconnect:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _headingBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tip('Check your Wi-Fi or cellular data'),
                        _tip('Try turning airplane mode off'),
                        _tip('Move to an area with better signal'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  CgPrimaryButton(
                    label: 'Try Again',
                    borderRadius: 12,
                    onPressed: () => _tryAgain(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onDestinationSelected: (i) => context.go(_tabPaths[i]),
      ),
    );
  }

  static Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 15, color: CgColors.blue700, height: 1.4)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray700),
            ),
          ),
        ],
      ),
    );
  }
}
