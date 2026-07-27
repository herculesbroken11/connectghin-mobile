import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/push/push_notifications.dart';
import '../../core/push/push_token_registry.dart';
import '../../core/widgets/cg_brand_header.dart';
import '../../core/widgets/cg_premium_badge.dart';
import '../../core/widgets/cg_switch.dart';
import '../location/location_device.dart';
import '../misc/data/account_api.dart';
import 'data/settings_api.dart';
import 'logout_confirm_dialog.dart';

/// Connectghin Settings — matches mockups; all profile/toggle values come from API.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  String _appVersionLabel = 'Connectghin';

  String _displayName = '';
  String _email = '';
  String? _photoUrl;
  bool _isPremium = false;
  String _membershipStatus = 'NONE';

  bool _notifyNewMatches = true;
  bool _notifyMessages = true;
  bool _notifyFoursomeFeed = false;

  bool _showLocation = true;
  bool _publicProfile = true;

  bool _savingSettings = false;
  bool _savingPrivacy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadPackageInfo();
      await _load();
    });
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersionLabel = 'Connectghin v${info.version}';
      });
    } catch (_) {
      // Keep fallback label.
    }
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final overview = await SettingsApi(session.apiClient).getOverview(t);
      final profile = overview['profile'] as Map<String, dynamic>? ?? {};
      final notifications = overview['notifications'] as Map<String, dynamic>? ?? {};
      final privacy = overview['privacy'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _displayName = (profile['displayName'] as String?)?.trim().isNotEmpty == true
            ? profile['displayName'] as String
            : 'Golfer';
        _email = profile['email'] as String? ?? '';
        _photoUrl = profile['photoUrl'] as String?;
        _isPremium = profile['isPremium'] == true;
        _membershipStatus = profile['membershipStatus'] as String? ?? 'NONE';
        _notifyNewMatches = notifications['notifyNewMatches'] as bool? ?? true;
        _notifyMessages = notifications['notifyMessages'] as bool? ?? true;
        _notifyFoursomeFeed = notifications['notifyFoursomeFeed'] as bool? ?? false;
        _showLocation = privacy['showLocation'] as bool? ?? true;
        _publicProfile = privacy['publicProfile'] as bool? ?? true;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showApiErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _patchNotification(String key, bool value, void Function(bool) revert) async {
    if (_savingSettings) return;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() => _savingSettings = true);
    try {
      await SettingsApi(session.apiClient).patchMe(
        accessToken: t,
        body: <String, bool>{key: value},
      );
      if (value && PushNotifications.isSupported) {
        final granted = await PushNotifications.requestPermission();
        if (!mounted) return;
        if (granted) {
          await PushTokenRegistry.requestResync();
        }
      }
    } catch (e) {
      if (mounted) {
        revert(!value);
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  bool get _showPremiumActive =>
      _isPremium && _membershipStatus != 'EXPIRED' && _membershipStatus != 'CANCELED';

  Future<void> _patchPrivacy(String key, bool value, void Function(bool) revert) async {
    if (_savingPrivacy) return;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() => _savingPrivacy = true);
    try {
      await AccountApi(session.apiClient).updatePrivacySettings(
        accessToken: t,
        body: <String, bool>{key: value},
      );
      if (key == 'showLocation' && value) {
        final err = await LocationDevice.requestAndSaveToProfile(session);
        if (!mounted) return;
        if (err != null) {
          showUserMessageSnackBar(context, err);
        } else {
          session.bumpProfileRefresh();
        }
      }
    } catch (e) {
      if (mounted) {
        revert(!value);
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _savingPrivacy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.cream,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CgColors.green700))
          : RefreshIndicator(
              color: CgColors.green700,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: CgBrandHeader(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: CgColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connectghin · Manage your account',
                            style: TextStyle(
                              color: CgColors.white.withValues(alpha: 0.82),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    sliver: SliverList.list(
                      children: [
                        _ProfileHeaderCard(
                          displayName: _displayName,
                          email: _email,
                          photoUrl: _photoUrl,
                          isPremium: _isPremium,
                          onTap: () => context.push(AppPaths.appProfile),
                        ),
                        const SizedBox(height: 14),
                        _SettingsCard(
                          sectionIcon: Icons.notifications_none_rounded,
                          sectionTitle: 'NOTIFICATIONS',
                          children: [
                            _switchRow(
                              title: 'New Matches',
                              subtitle: 'When someone matches with you.',
                              value: _notifyNewMatches,
                              onChanged: (v) {
                                setState(() => _notifyNewMatches = v);
                                _patchNotification('notifyNewMatches', v, (r) {
                                  if (mounted) setState(() => _notifyNewMatches = r);
                                });
                              },
                            ),
                            _switchRow(
                              title: 'Messages',
                              subtitle: 'When you receive a message.',
                              value: _notifyMessages,
                              onChanged: (v) {
                                setState(() => _notifyMessages = v);
                                _patchNotification('notifyMessages', v, (r) {
                                  if (mounted) setState(() => _notifyMessages = r);
                                });
                              },
                            ),
                            _switchRow(
                              title: 'Foursome Feed',
                              subtitle: 'When someone posts near you.',
                              value: _notifyFoursomeFeed,
                              onChanged: (v) {
                                setState(() => _notifyFoursomeFeed = v);
                                _patchNotification('notifyFoursomeFeed', v, (r) {
                                  if (mounted) setState(() => _notifyFoursomeFeed = r);
                                });
                              },
                              showDividerAfter: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _SettingsCard(
                          sectionIcon: Icons.shield_outlined,
                          sectionTitle: 'PRIVACY',
                          children: [
                            _switchRow(
                              title: 'Show my location',
                              subtitle: 'Visible to nearby golfers.',
                              value: _showLocation,
                              onChanged: (v) {
                                setState(() => _showLocation = v);
                                _patchPrivacy('showLocation', v, (r) {
                                  if (mounted) setState(() => _showLocation = r);
                                });
                              },
                            ),
                            _switchRow(
                              title: 'Public profile',
                              subtitle: 'Anyone can view your profile.',
                              value: _publicProfile,
                              onChanged: (v) {
                                setState(() => _publicProfile = v);
                                _patchPrivacy('publicProfile', v, (r) {
                                  if (mounted) setState(() => _publicProfile = r);
                                });
                              },
                              showDividerAfter: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _SettingsCard(
                          sectionIcon: Icons.person_outline_rounded,
                          sectionTitle: 'ACCOUNT',
                          children: [
                            _navRow(
                              icon: Icons.edit_outlined,
                              title: 'Edit Profile',
                              onTap: () => context.push(AppPaths.appProfileEdit),
                            ),
                            _navRow(
                              icon: Icons.location_on_outlined,
                              title: 'Location Settings',
                              onTap: () => context.push(AppPaths.appManualLocation),
                            ),
                            _navRow(
                              icon: Icons.lock_outline_rounded,
                              title: 'Change Password',
                              onTap: () => context.push(AppPaths.appChangePassword),
                            ),
                            _navRow(
                              icon: Icons.badge_outlined,
                              title: 'Change Username',
                              onTap: () => context.push(AppPaths.appChangeUsername),
                            ),
                            _navRow(
                              icon: Icons.mail_outline_rounded,
                              title: 'Change Email',
                              onTap: () => context.push(AppPaths.appChangeEmail),
                            ),
                            _navRow(
                              icon: Icons.photo_library_outlined,
                              title: 'Manage Photos',
                              onTap: () => context.push(AppPaths.appManagePhotos),
                              showDividerAfter: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _SettingsCard(
                          sectionIcon: Icons.workspace_premium_outlined,
                          sectionTitle: 'MEMBERSHIP',
                          children: [
                            _navRow(
                              icon: Icons.workspace_premium_rounded,
                              title: 'Premium Plan',
                              trailing: _isPremium
                                  ? _ActivePill(label: _showPremiumActive ? 'Active' : _membershipStatus)
                                  : null,
                              onTap: () => context.push(AppPaths.appMembership),
                            ),
                            _navRow(
                              icon: Icons.verified_user_outlined,
                              title: 'Handicap Verification',
                              onTap: () => context.push(AppPaths.appVerification),
                            ),
                            _navRow(
                              icon: Icons.credit_card_outlined,
                              title: 'Billing & Payments',
                              onTap: () => context.push(AppPaths.appMembership),
                              showDividerAfter: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _SettingsCard(
                          sectionIcon: Icons.lock_person_outlined,
                          sectionTitle: 'PRIVACY',
                          children: [
                            _navRow(
                              icon: Icons.tune_rounded,
                              title: 'Privacy Settings',
                              onTap: () => context.push(AppPaths.appPrivacySettings),
                            ),
                            _navRow(
                              icon: Icons.block_rounded,
                              title: 'Blocked Users',
                              onTap: () => context.push(AppPaths.appBlockedUsers),
                            ),
                            _navRow(
                              icon: Icons.policy_outlined,
                              title: 'Privacy Policy',
                              onTap: () => context.push(AppPaths.appPrivacyPolicy),
                              showDividerAfter: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _SettingsCard(
                          sectionIcon: Icons.help_outline_rounded,
                          sectionTitle: 'SUPPORT',
                          children: [
                            _navRow(
                              icon: Icons.support_agent_outlined,
                              title: 'Help & Support',
                              onTap: () => context.push(AppPaths.support),
                            ),
                            _navRow(
                              icon: Icons.article_outlined,
                              title: 'Terms of Service',
                              onTap: () => context.push(AppPaths.appTerms),
                            ),
                            _navRow(
                              icon: Icons.delete_outline_rounded,
                              title: 'Delete Account',
                              onTap: () => context.push(AppPaths.appDeleteAccount),
                              showDividerAfter: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Material(
                          color: const Color(0xFFFCE8E8),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => LogoutConfirmDialog.show(context),
                            borderRadius: BorderRadius.circular(14),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout_rounded, color: CgColors.destructive, size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'Sign Out',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: CgColors.destructive,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            _appVersionLabel,
                            style: const TextStyle(fontSize: 13, color: CgColors.gray500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _switchRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDividerAfter = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CgColors.gray900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 13, color: CgColors.gray500, height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
              CgSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (showDividerAfter) const Divider(height: 1, thickness: 1, color: CgColors.gray100),
      ],
    );
  }

  static Widget _navRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
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
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: CgColors.gray100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: CgColors.gray700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CgColors.gray900,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    trailing,
                    const SizedBox(width: 8),
                  ],
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
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.isPremium,
    required this.onTap,
  });

  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    return Material(
      color: CgColors.white,
      elevation: 0,
      shadowColor: CgColors.charcoal.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: CgColors.gray200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: url.isNotEmpty
                      ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                      : Container(
                          color: CgColors.gray200,
                          child: const Icon(Icons.person, color: CgColors.gray500, size: 28),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CgColors.gray900,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(email, style: const TextStyle(fontSize: 13, color: CgColors.gray500)),
                    ],
                    if (isPremium) ...[
                      const SizedBox(height: 8),
                      const CgPremiumBadge(compact: true),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: CgColors.gray400),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  const _ActivePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CgColors.yellow50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CgColors.yellow200),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: CgColors.premiumGoldDark,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.sectionTitle,
    required this.children,
    this.sectionIcon,
  });

  final String sectionTitle;
  final IconData? sectionIcon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CgColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: CgColors.gray200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                if (sectionIcon != null) ...[
                  Icon(sectionIcon, size: 16, color: CgColors.gray500),
                  const SizedBox(width: 8),
                ],
                Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: CgColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
