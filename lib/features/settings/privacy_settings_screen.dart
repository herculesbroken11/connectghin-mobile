import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_switch.dart';
import '../misc/data/account_api.dart';

/// GHINder privacy mock: grouped toggles (saved per change), data/account rows, disclaimer.
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _showInDiscovery = true;
  bool _showDistance = true;
  bool _showOnlineStatus = true;
  bool _showLastActive = false;
  bool _allowMessagesFromMatches = true;
  bool _showReadReceipts = true;
  bool _loading = true;
  String? _patchingKey;

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
      final row = await AccountApi(session.apiClient).getPrivacySettings(t);
      if (!mounted) return;
      setState(() {
        _showInDiscovery = row['showInDiscovery'] as bool? ?? true;
        _showDistance = row['showDistance'] as bool? ?? true;
        _showOnlineStatus = row['showOnlineStatus'] as bool? ?? true;
        _showLastActive = row['showLastActive'] as bool? ?? false;
        _allowMessagesFromMatches = row['allowMessagesFromMatches'] as bool? ?? true;
        _showReadReceipts = row['showReadReceipts'] as bool? ?? true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _patchBool(String key, bool value) async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final prev = _readLocal(key);
    _setLocal(key, value);
    setState(() {
      _patchingKey = key;
    });
    try {
      await AccountApi(session.apiClient).updatePrivacySettings(
        accessToken: t,
        body: <String, bool>{key: value},
      );
    } catch (e) {
      if (mounted) {
        _setLocal(key, prev);
        setState(() {});
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _patchingKey = null);
    }
  }

  bool _readLocal(String key) {
    switch (key) {
      case 'showInDiscovery':
        return _showInDiscovery;
      case 'showDistance':
        return _showDistance;
      case 'showOnlineStatus':
        return _showOnlineStatus;
      case 'showLastActive':
        return _showLastActive;
      case 'allowMessagesFromMatches':
        return _allowMessagesFromMatches;
      case 'showReadReceipts':
        return _showReadReceipts;
      default:
        return false;
    }
  }

  void _setLocal(String key, bool v) {
    switch (key) {
      case 'showInDiscovery':
        _showInDiscovery = v;
        break;
      case 'showDistance':
        _showDistance = v;
        break;
      case 'showOnlineStatus':
        _showOnlineStatus = v;
        break;
      case 'showLastActive':
        _showLastActive = v;
        break;
      case 'allowMessagesFromMatches':
        _allowMessagesFromMatches = v;
        break;
      case 'showReadReceipts':
        _showReadReceipts = v;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.white,
      appBar: AppBar(
        backgroundColor: CgColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: CgColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: const SizedBox.shrink(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CgColors.green700))
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Privacy Settings',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: CgColors.gray900),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Text(
                    'Control who can see your information',
                    style: TextStyle(fontSize: 15, color: CgColors.gray600, height: 1.35),
                  ),
                ),
                _sectionHeader('PROFILE VISIBILITY'),
                _toggleTile(
                  title: 'Show me in Discovery',
                  subtitle: 'Other users can see your profile when browsing.',
                  value: _showInDiscovery,
                  busy: _patchingKey == 'showInDiscovery',
                  onChanged: (v) => _patchBool('showInDiscovery', v),
                ),
                _toggleTile(
                  title: 'Show my distance',
                  subtitle: 'Display how far away you are from other users.',
                  value: _showDistance,
                  busy: _patchingKey == 'showDistance',
                  onChanged: (v) => _patchBool('showDistance', v),
                ),
                _sectionHeader('ACTIVITY STATUS'),
                _toggleTile(
                  title: 'Show online status',
                  subtitle: "Let others know when you're active.",
                  value: _showOnlineStatus,
                  busy: _patchingKey == 'showOnlineStatus',
                  onChanged: (v) => _patchBool('showOnlineStatus', v),
                ),
                _toggleTile(
                  title: 'Show last active',
                  subtitle: 'Display when you were last active.',
                  value: _showLastActive,
                  busy: _patchingKey == 'showLastActive',
                  onChanged: (v) => _patchBool('showLastActive', v),
                ),
                _sectionHeader('MESSAGING'),
                _toggleTile(
                  title: 'Allow messages from matches',
                  subtitle: 'Only matched users can message you.',
                  value: _allowMessagesFromMatches,
                  busy: _patchingKey == 'allowMessagesFromMatches',
                  onChanged: (v) => _patchBool('allowMessagesFromMatches', v),
                ),
                _toggleTile(
                  title: 'Send read receipts',
                  subtitle: "Let others know when you've read their messages.",
                  value: _showReadReceipts,
                  busy: _patchingKey == 'showReadReceipts',
                  onChanged: (v) => _patchBool('showReadReceipts', v),
                  showDividerAfter: false,
                ),
                _sectionHeader('DATA & ACCOUNT'),
                _linkTile(
                  title: 'Blocked Users',
                  subtitle: 'Manage blocked users.',
                  onTap: () => context.push(AppPaths.appBlockedUsers),
                ),
                _linkTile(
                  title: 'Download My Data',
                  subtitle: 'Request a copy of your data.',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Data export is coming soon. Use Help & Support to request a copy.'),
                      ),
                    );
                    context.push(AppPaths.support);
                  },
                ),
                _linkTile(
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account.',
                  destructive: true,
                  showDividerAfter: false,
                  onTap: () => context.push(AppPaths.appDeleteAccount),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CgColors.blue50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Your privacy matters. We never sell your data to third parties. Learn more in our ',
                          style: TextStyle(fontSize: 14, height: 1.45, color: CgColors.blue700),
                        ),
                        GestureDetector(
                          onTap: () => context.push(AppPaths.appPrivacyPolicy),
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: CgColors.blue700,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: CgColors.blue700,
                            ),
                          ),
                        ),
                        const Text(
                          '.',
                          style: TextStyle(fontSize: 14, color: CgColors.blue700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static Widget _sectionHeader(String t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      color: CgColors.gray100,
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: CgColors.gray600,
        ),
      ),
    );
  }

  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool busy = false,
    bool showDividerAfter = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CgColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: CgColors.gray600, height: 1.35),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: CircularProgressIndicator(strokeWidth: 2, color: CgColors.green700),
                  ),
                )
              else
                CgSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (showDividerAfter) const Divider(height: 1, thickness: 1, color: CgColors.gray100),
      ],
    );
  }

  Widget _linkTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
    bool showDividerAfter = true,
  }) {
    final titleColor = destructive ? CgColors.destructive : CgColors.gray900;
    final chevronColor = destructive ? CgColors.destructive : CgColors.gray400;
    return Column(
      children: [
        Material(
          color: CgColors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 13, color: CgColors.gray600, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: chevronColor),
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
