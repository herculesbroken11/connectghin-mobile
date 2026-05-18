import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';
import '../../core/widgets/cg_text_field.dart';
import '../misc/data/account_api.dart';
import '../profile/profile_screens.dart';
import '../profiles/data/profiles_api.dart';
import '../shell/app_bottom_nav_bar.dart';

export '../membership/membership_screens.dart';

// --- Settings & account (main Settings UI: `features/settings/settings_screen.dart`) ---

// --- Verification & safety ---

class ReportUserScreen extends StatefulWidget {
  const ReportUserScreen({super.key, this.targetUserId});

  /// Prefilled when opened as `/app/report-user?userId=...`.
  final String? targetUserId;

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  String? _reason;
  final _targetUserId = TextEditingController();
  final _details = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final pre = widget.targetUserId?.trim();
    if (pre != null && pre.isNotEmpty) {
      _targetUserId.text = pre;
    }
  }

  @override
  void dispose() {
    _targetUserId.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    final target = _targetUserId.text.trim();
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null || reason == null || target.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await AccountApi(session.apiClient).submitReport(
        accessToken: t,
        targetUserId: target,
        reason: reason,
        details: _details.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const options = ['Harassment', 'Fake profile', 'Inappropriate photos', 'Other'];
    return Scaffold(
      appBar: AppBar(title: const Text('Report user'), leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop())),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CgLabeledField(label: 'User ID', child: CgTextField(controller: _targetUserId, hint: 'Target user id')),
          const SizedBox(height: 12),
          const Text('Why are you reporting this profile?'),
          const SizedBox(height: 16),
          ...options.map(
            (r) => ListTile(
              title: Text(r),
              trailing: _reason == r ? const Icon(Icons.check_circle, color: CgColors.green700) : null,
              onTap: () => setState(() => _reason = r),
            ),
          ),
          const SizedBox(height: 16),
          CgTextField(controller: _details, hint: 'Additional details (optional)', keyboardType: TextInputType.multiline),
          const SizedBox(height: 24),
          CgPrimaryButton(label: _submitting ? 'Submitting…' : 'Submit report', onPressed: _submitting ? null : _submit),
        ],
      ),
    );
  }
}

class BlockUserScreen extends StatefulWidget {
  const BlockUserScreen({super.key, this.targetUserId});

  /// Prefilled when opened as `/app/block-user?userId=...`.
  final String? targetUserId;

  @override
  State<BlockUserScreen> createState() => _BlockUserScreenState();
}

class _BlockUserScreenState extends State<BlockUserScreen> {
  final _blockedUserId = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pre = widget.targetUserId?.trim();
    if (pre != null && pre.isNotEmpty) {
      _blockedUserId.text = pre;
    }
  }

  @override
  void dispose() {
    _blockedUserId.dispose();
    super.dispose();
  }

  Future<void> _block() async {
    final blocked = _blockedUserId.text.trim();
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null || blocked.isEmpty) return;
    setState(() => _saving = true);
    try {
      await AccountApi(session.apiClient).blockUser(accessToken: t, blockedUserId: blocked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Block user')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CgLabeledField(label: 'User ID', child: CgTextField(controller: _blockedUserId, hint: 'User to block')),
          const SizedBox(height: 12),
          const Text('They will not be able to message you or see your profile in discovery.'),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.32),
          CgPrimaryButton(
            label: _saving ? 'Blocking…' : 'Block',
            onPressed: _saving ? null : _block,
          ),
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(title: 'Terms of service', body: _lorem);
  }
}

const _lorem =
    'ConnectGHIN helps golfers discover matches, communicate, and manage golf-related profile information. '
    'We collect account details, profile content, and app activity needed to deliver matching and messaging features. '
    'You control profile visibility through privacy settings, and may request account deletion from Settings. '
    'By using the app, you agree to provide accurate information, follow community rules, and avoid harassment, abuse, or impersonation. '
    'Reports and blocks are reviewed to protect users and may result in moderation actions.';

class _LegalScaffold extends StatelessWidget {
  const _LegalScaffold({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => context.pop()),
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(body, style: const TextStyle(height: 1.6, color: CgColors.gray700)),
      ),
    );
  }
}

// --- Permissions & system states ---

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: Icons.location_on_outlined,
      title: 'Enable location',
      body: 'We use your location to show golfers nearby. You can change this anytime in settings.',
      primary: 'Allow location',
      onPrimary: () => context.pop(),
    );
  }
}

class NotificationPermissionScreen extends StatelessWidget {
  const NotificationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: Icons.notifications_active_outlined,
      title: 'Stay in the loop',
      body: 'Turn on notifications for new matches and messages.',
      primary: 'Allow notifications',
      onPrimary: () => context.pop(),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      body: 'Please try again. If the problem continues, contact support.',
      primary: 'Go home',
      onPrimary: () => context.go(AppPaths.app),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: Icons.search_off,
      title: 'Page not found',
      body: 'That screen does not exist.',
      primary: 'Home',
      onPrimary: () => context.go(AppPaths.welcome),
    );
  }
}

class _StateScaffold extends StatelessWidget {
  const _StateScaffold({
    required this.icon,
    required this.title,
    required this.body,
    required this.primary,
    required this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primary;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CgResponsiveContainer(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 64, color: CgColors.gray400),
                const SizedBox(height: 24),
                Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
                const SizedBox(height: 12),
                Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                CgPrimaryButton(label: primary, onPressed: onPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Profile sub-settings ---

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  bool _loading = true;
  bool _hasPhoto = false;
  bool _hasBio = false;
  bool _hasGolfPrefs = false;
  bool _hasHomeCourse = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    try {
      final me = await ProfilesApi(session.apiClient).getMe(t);
      final user = me['user'] as Map<String, dynamic>?;
      final photos = user?['profilePhotos'] as List<dynamic>? ?? [];
      final bio = (me['bio'] as String?)?.trim() ?? '';
      final home = (me['homeCourse'] as String?)?.trim() ?? '';
      final looking = (me['lookingFor'] as String?)?.trim() ?? '';
      final drink = (me['drinkingPreference'] as String?)?.trim() ?? '';
      final smoke = (me['smokingPreference'] as String?)?.trim() ?? '';
      final music = (me['musicPreference'] as String?)?.trim() ?? '';
      final hasHandicap = me['handicap'] != null;
      if (!mounted) return;
      setState(() {
        _hasPhoto = photos.isNotEmpty;
        _hasBio = bio.isNotEmpty;
        _hasGolfPrefs = hasHandicap || looking.isNotEmpty || drink.isNotEmpty || smoke.isNotEmpty || music.isNotEmpty;
        _hasHomeCourse = home.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _checkRow(String label, bool done, VoidCallback onTap) {
    return ListTile(
      leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? CgColors.green600 : CgColors.gray400),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CgColors.green700))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _checkRow('Profile photo', _hasPhoto, () => context.push(AppPaths.appManagePhotos)),
                _checkRow('Bio & about you', _hasBio, () => context.push(AppPaths.appProfileEdit)),
                _checkRow('Golf preferences', _hasGolfPrefs, () => context.push(AppPaths.appProfileEdit)),
                _checkRow('Home course', _hasHomeCourse, () => context.push(AppPaths.appProfileEdit)),
              ],
            ),
    );
  }
}

class PremiumFeaturesDemoScreen extends StatelessWidget {
  const PremiumFeaturesDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium features')),
      body: ListView(
        children: const [
          ListTile(title: Text('Unlimited swipes'), subtitle: Text('GHINder without daily limits')),
          ListTile(title: Text('Direct messages'), subtitle: Text('Reach out before matching')),
          ListTile(title: Text('Profile insights'), subtitle: Text('See who viewed you')),
        ],
      ),
    );
  }
}

class LogoutConfirmScreen extends StatelessWidget {
  const LogoutConfirmScreen({super.key});

  static const _tabPaths = <String>[
    AppPaths.app,
    AppPaths.appDiscover,
    AppPaths.appGhinder,
    AppPaths.appMatches,
    AppPaths.appProfile,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              child: InkWell(
                onTap: () => context.pop(),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Material(
                color: CgColors.white,
                elevation: 12,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFE4E6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.logout_rounded, size: 32, color: CgColors.destructive),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Log Out?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: CgColors.gray900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Are you sure you want to log out of your ConnectGHIN account?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: CgColors.gray700,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () async {
                              await context.read<AuthSession>().clear();
                              if (context.mounted) context.go(AppPaths.welcome);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CgColors.destructive,
                              foregroundColor: CgColors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => context.pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: CgColors.gray900,
                              side: const BorderSide(color: CgColors.gray300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 4,
        onDestinationSelected: (i) {
          context.pop();
          context.go(_tabPaths[i]);
        },
      ),
    );
  }
}

class ViewProfileAliasScreen extends StatelessWidget {
  const ViewProfileAliasScreen({super.key, this.userId});

  /// When set (e.g. `/app/view-profile?userId=...`), opens that golfer’s profile.
  /// Otherwise defaults to the signed-in user (legacy “my profile” shortcut).
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final fromQuery = userId?.trim();
    final id = (fromQuery != null && fromQuery.isNotEmpty)
        ? fromQuery
        : context.watch<AuthSession>().userId;
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Sign in to view this profile.')),
      );
    }
    return ViewProfileScreen(userId: id);
  }
}

class ChangeEmailScreen extends StatelessWidget {
  const ChangeEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          CgLabeledField(label: 'Email', child: CgTextField(hint: 'you@example.com', keyboardType: TextInputType.emailAddress)),
          SizedBox(height: 12),
          Text(
            'Email updates are not available yet in this backend build. '
            'Use your current email for login and contact support for changes.',
            style: TextStyle(color: CgColors.gray600),
          ),
        ],
      ),
    );
  }
}

