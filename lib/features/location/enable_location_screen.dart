import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';
import '../shell/app_bottom_nav_bar.dart';
import 'location_device.dart';

/// Shown inside GHINder / Discover when the profile has no city or coordinates yet.
class EnableLocationPanel extends StatefulWidget {
  const EnableLocationPanel({
    super.key,
    required this.onSaved,
    required this.onSkipManual,
  });

  final VoidCallback onSaved;
  final VoidCallback onSkipManual;

  @override
  State<EnableLocationPanel> createState() => _EnableLocationPanelState();
}

class _EnableLocationPanelState extends State<EnableLocationPanel> {
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    final session = context.read<AuthSession>();
    final err = await LocationDevice.requestAndSaveToProfile(session);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: CgResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: CgColors.green50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_outlined, size: 40, color: CgColors.green700),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Enable Location',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: CgColors.gray900,
                  ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Find golfers near you and discover courses in your area',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray600),
            ),
            const SizedBox(height: 28),
            _bulletRow('See golfers nearby', 'Connect with players in your area'),
            const SizedBox(height: 14),
            _bulletRow('Discover local courses', 'Find great places to play near you'),
            const SizedBox(height: 14),
            _bulletRow('Better matches', 'Get matched with golfers you can meet'),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CgColors.blue50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 14, height: 1.45, color: CgColors.blue700),
                  children: [
                    TextSpan(
                      text: 'Your privacy matters\n',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text:
                          'We only use your location to show you nearby golfers. Your exact location is never shared.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            CgPrimaryButton(
              label: _busy ? 'Working…' : 'Enable Location',
              borderRadius: 12,
              onPressed: _busy ? null : _enable,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _busy ? null : widget.onSkipManual,
                child: const Text(
                  'Skip for Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CgColors.gray700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bulletRow(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: CgColors.green700, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CgColors.gray900),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, height: 1.4, color: CgColors.gray600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Full-screen route (e.g. from Settings) — same content + bottom tabs.
class EnableLocationScreen extends StatelessWidget {
  const EnableLocationScreen({super.key});

  static const _tabPaths = <String>[
    AppPaths.app,
    AppPaths.appDiscover,
    AppPaths.appGhinder,
    AppPaths.appMatches,
    AppPaths.appSettings,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.white,
      body: SafeArea(
        bottom: false,
        child: EnableLocationPanel(
          onSaved: () => context.go(AppPaths.appGhinder),
          onSkipManual: () => context.push(AppPaths.appManualLocation),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onDestinationSelected: (i) => context.go(_tabPaths[i]),
      ),
    );
  }
}
