import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/push/push_notifications.dart';
import '../../core/push/push_token_registry.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';
import '../../core/widgets/cg_text_field.dart';
import '../location/location_device.dart';
import '../misc/data/account_api.dart';
import '../profile/profile_screens.dart';
import '../profiles/data/profiles_api.dart';
import '../settings/logout_confirm_dialog.dart';

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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Report submitted')));
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
    const options = [
      'Harassment',
      'Fake profile',
      'Inappropriate photos',
      'Other'
    ];
    return Scaffold(
      appBar: AppBar(
          title: const Text('Report user'),
          leading: IconButton(
              icon: const Icon(Icons.close), onPressed: () => context.pop())),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.targetUserId == null ||
              widget.targetUserId!.trim().isEmpty) ...[
            CgLabeledField(
                label: 'User ID',
                child: CgTextField(
                    controller: _targetUserId, hint: 'Target user id')),
            const SizedBox(height: 12),
          ],
          const Text('Why are you reporting this profile?'),
          const SizedBox(height: 16),
          ...options.map(
            (r) => ListTile(
              title: Text(r),
              trailing: _reason == r
                  ? const Icon(Icons.check_circle, color: CgColors.green700)
                  : null,
              onTap: () => setState(() => _reason = r),
            ),
          ),
          const SizedBox(height: 16),
          CgTextField(
              controller: _details,
              hint: 'Additional details (optional)',
              keyboardType: TextInputType.multiline),
          const SizedBox(height: 24),
          CgPrimaryButton(
              label: _submitting ? 'Submitting…' : 'Submit report',
              onPressed: _submitting ? null : _submit),
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
      await AccountApi(session.apiClient)
          .blockUser(accessToken: t, blockedUserId: blocked);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User blocked')));
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
          CgLabeledField(
              label: 'User ID',
              child: CgTextField(
                  controller: _blockedUserId, hint: 'User to block')),
          const SizedBox(height: 12),
          const Text(
              'They will not be able to message you or see your profile in discovery.'),
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.32),
          CgPrimaryButton(
            label: _saving ? 'Blocking…' : 'Block',
            onPressed: _saving ? null : _block,
          ),
          TextButton(
              onPressed: () => context.pop(), child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(title: 'Terms of service', body: _termsBody);
  }
}

const _termsBody =
    'Last updated: August 31, 2026\n\n'
    '1. Acceptance\n'
    'By creating an account or using Connectghin, you agree to these Terms of Service and our Privacy Policy. '
    'If you do not agree, do not use the app.\n\n'
    '2. Eligibility\n'
    'You must be at least 18 years old to use Connectghin. The app is intended for golfers seeking playing partners '
    'and related social features.\n\n'
    '3. Accounts\n'
    'You are responsible for accurate account information and for activity under your account. '
    'You may request account deletion from Settings or at https://connectghin.com/delete-account. '
    'Verified requests are processed using our standard deletion workflow (data deleted or anonymized). '
    'Google Play or App Store subscriptions must be managed separately in the store. '
    'Paid subscriptions billed through Google Play or the App Store must be managed in those stores.\n\n'
    '4. Acceptable use\n'
    'You agree not to harass, abuse, impersonate, spam, scrape, or otherwise misuse the service. '
    'Do not post unlawful, hateful, or sexually explicit content. We may remove content and suspend or terminate '
    'accounts that violate these rules.\n\n'
    '5. User content & safety\n'
    'You retain rights to content you submit (profiles, photos, Feed posts, messages, and ratings). '
    'You grant Connectghin a license to host and display that content to operate the service. '
    'You can report and block other users. Reports may lead to moderation actions including content removal or suspension.\n\n'
    '6. Handicap information\n'
    'Handicap details you submit may be reviewed for a Handicap Verified badge. '
    'Connectghin is not affiliated with, endorsed by, or operated by any third-party handicap authority. '
    'Verification in the app is based on information you provide and our review process—not an official external certification.\n\n'
    '7. Premium subscriptions\n'
    'Optional Premium membership is sold through Google Play or the App Store. '
    'Benefits shown in the Membership screen apply while your Premium entitlement is active. '
    'Billing, renewals, and cancellations follow the store’s terms.\n\n'
    '8. Disclaimers\n'
    'Connectghin is provided “as is.” We do not guarantee matches, playing partners, or uninterrupted service. '
    'You are responsible for real-world interactions arranged through the app.\n\n'
    '9. Limitation of liability\n'
    'To the fullest extent permitted by law, Connectghin and its operators are not liable for indirect, incidental, '
    'or consequential damages arising from use of the app.\n\n'
    '10. Contact\n'
    'Questions about these Terms: support@connectghin.com';

class _LegalScaffold extends StatelessWidget {
  const _LegalScaffold({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.pop()),
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(body,
            style: const TextStyle(height: 1.6, color: CgColors.gray700)),
      ),
    );
  }
}

// --- Permissions & system states ---

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _busy = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    final session = context.read<AuthSession>();
    final err = await LocationDevice.requestAndSaveToProfile(session);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showUserMessageSnackBar(context, err);
      return;
    }
    showUserMessageSnackBar(context, 'Location saved to your profile.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: Icons.location_on_outlined,
      title: 'Enable location',
      body:
          'We use your location to show golfers nearby. You can change this anytime in settings.',
      primary: _busy ? 'Working…' : 'Allow location',
      onPrimary: _busy ? null : _allow,
    );
  }
}

class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen> {
  bool _busy = false;

  Future<void> _allow() async {
    if (!PushNotifications.isSupported) {
      if (!mounted) return;
      showUserMessageSnackBar(
        context,
        'Push notifications are not set up on this device yet.',
      );
      context.pop();
      return;
    }
    setState(() => _busy = true);
    try {
      final granted = await PushNotifications.requestPermission();
      if (granted) {
        await PushTokenRegistry.requestResync();
        if (!mounted) return;
        context.pop();
        return;
      }
      if (!mounted) return;
      showUserMessageSnackBar(
        context,
        'Notifications are off. You can enable them in system settings.',
      );
      await Geolocator.openAppSettings();
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: Icons.notifications_active_outlined,
      title: 'Stay in the loop',
      body:
          'Allow notifications for new matches and messages. You can change this anytime in Settings.',
      primary: _busy ? 'Working…' : 'Allow notifications',
      onPrimary: _busy ? null : _allow,
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
  final VoidCallback? onPrimary;

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
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontSize: 22)),
                const SizedBox(height: 12),
                Text(body,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
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
        _hasPhoto = photos.length >= 2;
        _hasBio = bio.isNotEmpty;
        _hasGolfPrefs = hasHandicap ||
            looking.isNotEmpty ||
            drink.isNotEmpty ||
            smoke.isNotEmpty ||
            music.isNotEmpty;
        _hasHomeCourse = home.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _checkRow(String label, bool done, VoidCallback onTap) {
    return ListTile(
      leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? CgColors.green600 : CgColors.gray400),
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
          ? const Center(
              child: CircularProgressIndicator(color: CgColors.green700))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _checkRow('At least 2 profile photos', _hasPhoto,
                    () => context.push(AppPaths.appManagePhotos)),
                _checkRow('Bio & about you', _hasBio,
                    () => context.push(AppPaths.appProfileEdit)),
                _checkRow('Golf preferences', _hasGolfPrefs,
                    () => context.push(AppPaths.appProfileEdit)),
                _checkRow('Home course', _hasHomeCourse,
                    () => context.push(AppPaths.appProfileEdit)),
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
          ListTile(
              title: Text('Unlimited Connect likes'),
              subtitle: Text('No daily Connect limit')),
          ListTile(
              title: Text('Full Feed access'),
              subtitle: Text('Browse all posts, publish open spots, contact posters')),
          ListTile(
              title: Text('Premium badge'),
              subtitle: Text('Show Premium on your profile')),
        ],
      ),
    );
  }
}

/// Legacy route: opens the same dialog as Settings (avoids full-screen black backdrop).
class LogoutConfirmScreen extends StatefulWidget {
  const LogoutConfirmScreen({super.key});

  @override
  State<LogoutConfirmScreen> createState() => _LogoutConfirmScreenState();
}

class _LogoutConfirmScreenState extends State<LogoutConfirmScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await LogoutConfirmDialog.show(context);
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: CgColors.gray50,
      body: SizedBox.shrink(),
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
          CgLabeledField(
              label: 'Email',
              child: CgTextField(
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress)),
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
