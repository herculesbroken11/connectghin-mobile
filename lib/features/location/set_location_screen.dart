import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_text_field.dart';
import '../profiles/data/profiles_api.dart';
import '../shell/app_bottom_nav_bar.dart';
import 'location_device.dart';

/// Manual city/state/zip + optional automatic location (full-screen route).
class SetLocationScreen extends StatefulWidget {
  const SetLocationScreen({super.key});

  @override
  State<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends State<SetLocationScreen> {
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  bool _saving = false;
  bool _gpsBusy = false;

  static const _tabPaths = <String>[
    AppPaths.app,
    AppPaths.appDiscover,
    AppPaths.appGhinder,
    AppPaths.appMatches,
    AppPaths.appProfile,
  ];

  @override
  void dispose() {
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    super.dispose();
  }

  Future<void> _enableGps() async {
    setState(() => _gpsBusy = true);
    final session = context.read<AuthSession>();
    final err = await LocationDevice.requestAndSaveToProfile(session);
    if (!mounted) return;
    setState(() => _gpsBusy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location saved')));
    _finish();
  }

  Future<void> _continueManual() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final city = _city.text.trim();
    final state = _state.text.trim().toUpperCase();
    final zip = _zip.text.trim();
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a city')));
      return;
    }
    if (state.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a state')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ProfilesApi(session.apiClient).updateMe(
        accessToken: t,
        body: <String, dynamic>{
          'city': city,
          'state': state,
          if (zip.isNotEmpty) 'postalCode': zip,
        },
      );
      if (!mounted) return;
      session.bumpProfileRefresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location saved')));
      _finish();
    } catch (e) {
      if (!mounted) return;
      showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _finish() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppPaths.appGhinder);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.white,
      appBar: AppBar(
        backgroundColor: CgColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: CgColors.gray900, size: 28),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppPaths.appGhinder);
            }
          },
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: CgResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: CgColors.green50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_outlined, size: 36, color: CgColors.green700),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Set Your Location',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: CgColors.gray900,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Required for discovery',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: CgColors.gray600),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CgColors.green700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enable Automatic Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: CgColors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Get the best discovery experience by allowing ConnectGHIN to access your location',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: CgColors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Material(
                        color: CgColors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _gpsBusy || _saving ? null : _enableGps,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_on, color: CgColors.green700, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  _gpsBusy ? 'Working…' : 'Enable Location Services',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: CgColors.green700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Row(
                  children: [
                    Expanded(child: Divider(color: CgColors.gray200, height: 1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or enter manually',
                        style: TextStyle(fontSize: 13, color: CgColors.gray500, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(child: Divider(color: CgColors.gray200, height: 1)),
                  ],
                ),
                const SizedBox(height: 24),
                CgLabeledField(
                  label: 'City',
                  child: CgTextField(controller: _city, hint: 'San Francisco'),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: CgLabeledField(
                        label: 'State',
                        child: CgTextField(controller: _state, hint: 'CA'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: CgLabeledField(
                        label: 'Zip Code (Optional)',
                        child: CgTextField(controller: _zip, hint: '94102', keyboardType: TextInputType.number),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                CgPrimaryButton(
                  label: _saving ? 'Saving…' : 'Continue',
                  borderRadius: 12,
                  onPressed: _saving || _gpsBusy ? null : _continueManual,
                ),
                const SizedBox(height: 24),
                _infoCard(),
                const SizedBox(height: 16),
                _warningCard(),
              ],
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

  static Widget _infoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CgColors.blue50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: CgColors.blue700, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Why we need your location',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CgColors.blue700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bullet('Show you nearby golfers', CgColors.blue700),
                _bullet('Connect you with players at local courses', CgColors.blue700),
                _bullet('Improve match quality', CgColors.blue700),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your exact location is never shared with other users. We only show approximate distance.',
            style: TextStyle(fontSize: 13, height: 1.45, color: CgColors.blue700.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  static Widget _bullet(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: color, fontSize: 14, height: 1.4)),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, height: 1.4, color: color)),
          ),
        ],
      ),
    );
  }

  static Widget _warningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CgColors.yellow50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CgColors.yellow200),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: CgColors.yellow700, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Without location services, you'll see fewer potential matches and won't appear in nearby searches.",
              style: TextStyle(fontSize: 13, height: 1.45, color: CgColors.yellow900),
            ),
          ),
        ],
      ),
    );
  }
}
