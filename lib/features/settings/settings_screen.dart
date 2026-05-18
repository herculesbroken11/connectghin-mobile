import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../misc/data/account_api.dart';
import 'data/settings_api.dart';

/// Matches GHINder settings mockups: grouped sections, toggles, icons, version, log out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const _appVersion = '1.0.0';

  static const _kPrefNotifyMatches = 'settings_notify_new_matches';
  static const _kPrefNotifyMessages = 'settings_notify_new_messages';
  static const _kPrefLocation = 'settings_location_services_opt_in';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;

  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _notifyMatches = true;
  bool _notifyMessages = true;

  bool _showInDiscovery = true;
  bool _locationOptIn = true;

  bool _savingSettings = false;
  bool _savingPrivacy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final api = SettingsApi(session.apiClient);
      final row = await api.getMe(t);
      final privacy = await AccountApi(session.apiClient).getPrivacySettings(t);
      if (!mounted) return;
      setState(() {
        _pushEnabled = row?['pushEnabled'] as bool? ?? true;
        _emailEnabled = row?['emailEnabled'] as bool? ?? true;
        _notifyMatches = prefs.getBool(SettingsScreen._kPrefNotifyMatches) ?? true;
        _notifyMessages = prefs.getBool(SettingsScreen._kPrefNotifyMessages) ?? true;
        _showInDiscovery = privacy['showInDiscovery'] as bool? ?? true;
        _locationOptIn = prefs.getBool(SettingsScreen._kPrefLocation) ?? true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persistPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsScreen._kPrefNotifyMatches, _notifyMatches);
    await prefs.setBool(SettingsScreen._kPrefNotifyMessages, _notifyMessages);
    await prefs.setBool(SettingsScreen._kPrefLocation, _locationOptIn);
  }

  Future<void> _patchUserSettings(Map<String, bool> patch) async {
    if (_savingSettings) return;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() => _savingSettings = true);
    try {
      await SettingsApi(session.apiClient).patchMe(accessToken: t, body: patch);
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _patchShowInDiscovery(bool v) async {
    if (_savingPrivacy) return;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() {
      _showInDiscovery = v;
      _savingPrivacy = true;
    });
    try {
      await AccountApi(session.apiClient).updatePrivacySettings(
        accessToken: t,
        body: <String, bool>{'showInDiscovery': v},
      );
    } catch (e) {
      if (mounted) {
        setState(() => _showInDiscovery = !v); // revert optimistic update
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _savingPrivacy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.gray50,
      appBar: AppBar(
        backgroundColor: CgColors.gray50,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: CgColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CgColors.gray900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CgColors.green700))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _SettingsCard(
                  children: [
                    _sectionBand('ACCOUNT'),
                    _navRow(
                      context,
                      icon: Icons.person_outline_rounded,
                      title: 'Edit Profile',
                      onTap: () => context.push(AppPaths.appProfileEdit),
                    ),
                    _navRow(
                      context,
                      icon: Icons.verified_user_outlined,
                      title: 'GHIN Verification',
                      onTap: () => context.push(AppPaths.appVerification),
                    ),
                    _navRow(
                      context,
                      icon: Icons.lock_outline_rounded,
                      title: 'Change Password',
                      onTap: () => context.push(AppPaths.appChangePassword),
                    ),
                    _navRow(
                      context,
                      icon: Icons.badge_outlined,
                      title: 'Change Username',
                      onTap: () => context.push(AppPaths.appChangeUsername),
                    ),
                    _navRow(
                      context,
                      icon: Icons.mail_outline_rounded,
                      title: 'Change Email',
                      onTap: () => context.push(AppPaths.appChangeEmail),
                    ),
                    _navRow(
                      context,
                      icon: Icons.photo_library_outlined,
                      title: 'Manage Photos',
                      onTap: () => context.push(AppPaths.appManagePhotos),
                      showDividerAfter: false,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _sectionBand('NOTIFICATIONS'),
                    _switchRow(
                      title: 'Push Notifications',
                      value: _pushEnabled,
                      onChanged: (v) {
                        setState(() => _pushEnabled = v);
                        _patchUserSettings(<String, bool>{'pushEnabled': v});
                      },
                    ),
                    _switchRow(
                      title: 'New Matches',
                      value: _notifyMatches,
                      onChanged: (v) {
                        setState(() => _notifyMatches = v);
                        _persistPrefs();
                      },
                    ),
                    _switchRow(
                      title: 'New Messages',
                      value: _notifyMessages,
                      onChanged: (v) {
                        setState(() => _notifyMessages = v);
                        _persistPrefs();
                      },
                    ),
                    _switchRow(
                      title: 'Email Notifications',
                      value: _emailEnabled,
                      onChanged: (v) {
                        setState(() => _emailEnabled = v);
                        _patchUserSettings(<String, bool>{'emailEnabled': v});
                      },
                      showDividerAfter: false,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _sectionBand('DISCOVERY'),
                    _switchRow(
                      title: 'Show me in Discovery',
                      value: _showInDiscovery,
                      onChanged: _patchShowInDiscovery,
                    ),
                    _switchRow(
                      title: 'Location Services',
                      value: _locationOptIn,
                      onChanged: (v) {
                        setState(() => _locationOptIn = v);
                        _persistPrefs();
                      },
                    ),
                    _navRow(
                      context,
                      icon: Icons.location_on_outlined,
                      title: 'Set your location',
                      subtitle: 'City or GPS for Discover & GHINder',
                      onTap: () => context.push(AppPaths.appManualLocation),
                      showDividerAfter: false,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _sectionBand('SAFETY & PRIVACY'),
                    _navRow(
                      context,
                      icon: Icons.lock_person_outlined,
                      title: 'Privacy Settings',
                      onTap: () => context.push(AppPaths.appPrivacySettings),
                    ),
                    _navRow(
                      context,
                      icon: Icons.block_rounded,
                      title: 'Blocked Users',
                      onTap: () => context.push(AppPaths.appBlockedUsers),
                    ),
                    _navRow(
                      context,
                      icon: Icons.report_problem_outlined,
                      title: 'Report a Problem',
                      onTap: () => context.push(AppPaths.support),
                      showDividerAfter: false,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _sectionBand('ABOUT'),
                    _navRow(
                      context,
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      onTap: () => context.push(AppPaths.support),
                    ),
                    _versionRow(),
                    _navRow(
                      context,
                      icon: Icons.description_outlined,
                      title: 'Privacy Policy',
                      onTap: () => context.push(AppPaths.appPrivacyPolicy),
                    ),
                    _navRow(
                      context,
                      icon: Icons.article_outlined,
                      title: 'Terms of Service',
                      onTap: () => context.push(AppPaths.appTerms),
                    ),
                    _navRow(
                      context,
                      icon: Icons.workspace_premium_outlined,
                      title: 'Membership',
                      onTap: () => context.push(AppPaths.appMembership),
                      showDividerAfter: false,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Material(
                      color: CgColors.white,
                      elevation: 1,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: CgColors.gray200),
                      ),
                      child: InkWell(
                        onTap: () => context.push(AppPaths.appLogoutConfirm),
                        borderRadius: BorderRadius.circular(14),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: CgColors.destructive, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Log Out',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CgColors.destructive,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.push(AppPaths.appDeleteAccount),
                    child: const Text(
                      'Delete account',
                      style: TextStyle(color: CgColors.gray600, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static Widget _sectionBand(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: CgColors.gray100,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: CgColors.gray600,
        ),
      ),
    );
  }

  static Widget _navRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    bool showDividerAfter = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: CgColors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: CgColors.gray700),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: CgColors.gray900,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: CgColors.gray500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: CgColors.gray400),
                ],
              ),
            ),
          ),
        ),
        if (showDividerAfter) const Divider(height: 1, thickness: 1, color: CgColors.gray100),
      ],
    );
  }

  Widget _switchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDividerAfter = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: CgColors.gray900,
                    ),
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: CgColors.white,
                activeTrackColor: CgColors.gray900,
                inactiveThumbColor: CgColors.white,
                inactiveTrackColor: CgColors.gray300,
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ],
          ),
        ),
        if (showDividerAfter) const Divider(height: 1, thickness: 1, color: CgColors.gray100),
      ],
    );
  }

  static Widget _versionRow() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Version',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: CgColors.gray900,
                  ),
                ),
              ),
              Text(
                SettingsScreen._appVersion,
                style: TextStyle(fontSize: 15, color: CgColors.gray500),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: CgColors.gray100),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CgColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: CgColors.gray200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
