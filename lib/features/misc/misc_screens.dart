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
import '../settings/legal_rich_text.dart';
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

  static const _sections = <(String, String)>[
    (
      '1. Acceptance of Terms',
      'By accessing or using Connectghin, you agree to these Terms of Service and our Privacy Policy (https://connectghin.com/privacy). If you do not agree, do not use the service.',
    ),
    (
      '2. Eligibility',
      'Connectghin is intended only for users who are 18 years of age or older. By creating or using an account, you represent that you are at least 18.',
    ),
    (
      '3. Description of Service',
      'Connectghin is a social golf platform. Features may allow you to create and manage a golfer profile, find nearby golfers, send Connect requests or likes, form Matches through mutual connections, message matched users, browse The Feed, post or respond to open golf spots where permitted, provide golf and handicap information, and use Premium features when subscribed.\n\n'
          'Where applicable, a “Handicap Verified” badge reflects Connectghin’s internal or manual review. Connectghin is not affiliated with, endorsed by, or sponsored by the United States Golf Association (USGA) or the GHIN service unless expressly stated otherwise. Third-party names and trademarks remain the property of their respective owners. A Connectghin “Handicap Verified” badge is not an official USGA or GHIN certification.',
    ),
    (
      '4. User Accounts',
      'Provide accurate information and keep it current. You are responsible for protecting your credentials, maintaining account security, and activity under your account. Notify us if you suspect unauthorized access. We may suspend or terminate accounts that violate these Terms.',
    ),
    (
      '5. User-Generated Content and Content Rights',
      'You retain ownership of content you submit. You grant Connectghin a non-exclusive license to host, store, reproduce, display, transmit and make your submitted content available solely as necessary to operate, improve, moderate and provide the service. This includes profile information, photos, Feed and open-spot posts, reviews, ratings and other submissions where applicable.\n\n'
          'You represent that you own or have the necessary rights and permissions for what you submit. Do not submit material that infringes another person’s copyright, trademark, privacy, publicity or other rights, or illegal, abusive, threatening, fraudulent, exploitative or harmful content. We may remove or restrict content when reasonably necessary for safety, Terms enforcement, legal compliance or operation of the service.',
    ),
    (
      '6. Community Conduct and Safety',
      'Do not harass, threaten or abuse others; impersonate others; mislead or defraud; spam; engage in unlawful activity; post inappropriate or sexually exploitative content, including child sexual abuse or exploitation material; bypass moderation; attempt unauthorized access; or use another person’s information without authorization. See our Child Safety Standards (https://connectghin.com/child-safety).',
    ),
    (
      '7. Reporting, Blocking and Moderation',
      'Safety tools may include reporting users or Feed content, blocking users, review of reports, content removal or restriction, and account suspension or termination. Reports may be submitted through available tools or to support@connectghin.com. Review is not instantaneous, and no platform can guarantee complete safety at all times.',
    ),
    (
      '8. Subscriptions and Billing',
      'Free access and Connectghin Premium may be available. Premium may be offered as monthly or yearly auto-renewable subscriptions. For mobile purchases, iOS subscriptions are processed by the Apple App Store and Android subscriptions by Google Play. The price and renewal terms shown before purchase govern; subscriptions renew automatically unless canceled under the applicable store’s rules. Manage or cancel through your Apple Account/App Store or Google Play subscription settings. Refunds are governed by the applicable store’s policies. Deleting your account does not automatically cancel a store subscription.',
    ),
    (
      '9. Third-Party Services',
      'The service may rely on third parties for operational services such as authentication, app-store billing, push notifications, email delivery, hosting and location features, where applicable.',
    ),
    (
      '10. Account Deletion',
      'You may initiate deletion in the mobile app under Settings → Delete Account or at https://connectghin.com/delete-account. Personal account information may be deleted or anonymized. Some records may be retained where reasonably necessary for legal compliance, fraud or security, moderation or safety, transaction and accounting records, or disputes. Deleting a Connectghin account does not automatically cancel an Apple App Store or Google Play subscription.',
    ),
    (
      '11. Intellectual Property',
      'Connectghin retains rights to its original software, branding and content. User submissions remain governed by Section 5. Third-party trademarks belong to their respective owners.',
    ),
    (
      '12. Disclaimers and Limitation of Liability',
      'To the extent permitted by applicable law, the service is provided without a guarantee of uninterrupted availability. Connectghin is not liable for indirect, incidental, special or consequential damages arising from use of the service. Nothing here limits rights or remedies that cannot lawfully be excluded.',
    ),
    (
      '13. Changes',
      'We may update these Terms. Updated Terms will be posted here with a revised “Last updated” date.',
    ),
    (
      '14. Contact',
      'Questions? Contact support@connectghin.com.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Terms of service'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          const Text(
            'Last updated: September 30, 2026',
            style: TextStyle(fontSize: 15, color: CgColors.gray600, height: 1.35),
          ),
          const SizedBox(height: 20),
          for (final section in _sections) ...[
            Text(
              section.$1,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: CgColors.gray900,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            LegalRichText(section.$2),
            const SizedBox(height: 18),
          ],
        ],
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
        final token = await PushNotifications.getToken();
        if (!mounted) return;
        if (token == null || token.isEmpty) {
          showUserMessageSnackBar(
            context,
            'Notifications could not be enabled right now. Please try again later.',
          );
        }
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
    } catch (e) {
      if (!mounted) return;
      showUserMessageSnackBar(
        context,
        messageFromApiError(
          e,
          fallback:
              'Notifications could not be enabled right now. Please try again later.',
        ),
      );
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
