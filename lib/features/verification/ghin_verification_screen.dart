import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_text_field.dart';
import '../misc/data/account_api.dart';

/// Multi-step GHIN verification flow aligned with product designs (intro → form → pending / success / rejected).
class GhinVerificationScreen extends StatefulWidget {
  const GhinVerificationScreen({super.key});

  @override
  State<GhinVerificationScreen> createState() => _GhinVerificationScreenState();
}

enum _Pane { intro, form, pending, success, rejected }

class _GhinVerificationScreenState extends State<GhinVerificationScreen> {
  final _ghin = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();

  Map<String, dynamic>? _latest;
  _Pane _pane = _Pane.intro;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  /// After "Try again" from rejected, form back returns to rejected.
  bool _formReturnToRejected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _ghin.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await AccountApi(session.apiClient).ghinStatus(t);
      if (!mounted) return;
      setState(() {
        _applyServerRow(row);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = messageFromApiError(e);
        _loading = false;
      });
    }
  }

  void _applyServerRow(Map<String, dynamic>? row) {
    _latest = row;
    if (row == null) {
      _pane = _formReturnToRejected ? _Pane.rejected : _Pane.intro;
      return;
    }
    final st = row['status']?.toString() ?? '';
    switch (st) {
      case 'PENDING':
      case 'APPEAL':
        _pane = _Pane.pending;
        break;
      case 'VERIFIED':
        _pane = _Pane.success;
        break;
      case 'REJECTED':
        _pane = _Pane.rejected;
        break;
      default:
        _pane = _Pane.pending;
    }
  }

  Future<void> _submit() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final ghin = _ghin.text.trim();
    final fn = _first.text.trim();
    final ln = _last.text.trim();
    if (ghin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your GHIN number')));
      return;
    }
    if (fn.isEmpty || ln.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter first and last name')));
      return;
    }
    setState(() => _saving = true);
    try {
      await AccountApi(session.apiClient).submitGhin(
        accessToken: t,
        ghinNumber: ghin,
        submittedFirstName: fn,
        submittedLastName: ln,
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted for verification')));
      }
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openForm() {
    setState(() {
      _pane = _Pane.form;
      _formReturnToRejected = false;
    });
  }

  void _tryAgainFromRejected() {
    final row = _latest;
    _ghin.text = (row != null && row['ghinNumber']?.toString() != 'APPEAL')
        ? row['ghinNumber']?.toString() ?? ''
        : '';
    _first.text = row?['submittedFirstName']?.toString() ?? '';
    _last.text = row?['submittedLastName']?.toString() ?? '';
    setState(() {
      _pane = _Pane.form;
      _formReturnToRejected = true;
    });
  }

  void _onFormBack() {
    if (_formReturnToRejected) {
      setState(() {
        _pane = _Pane.rejected;
        _formReturnToRejected = false;
      });
    } else {
      setState(() => _Pane.intro);
    }
  }

  String _displayNameLine() {
    final row = _latest;
    final a = row?['submittedFirstName']?.toString().trim() ?? '';
    final b = row?['submittedLastName']?.toString().trim() ?? '';
    if (a.isEmpty && b.isEmpty) return '—';
    return '$a $b'.trim();
  }

  String _displayGhin() {
    final g = _latest?['ghinNumber']?.toString() ?? '';
    if (g == 'APPEAL') return '—';
    return g.isEmpty ? '—' : g;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: CgColors.gray50,
        body: Center(child: CircularProgressIndicator(color: CgColors.green700)),
      );
    }

    return Scaffold(
      backgroundColor: CgColors.gray50,
      body: SafeArea(
        child: switch (_pane) {
          _Pane.intro => _IntroBody(
              error: _error,
              onBack: () => context.pop(),
              onStart: _openForm,
              onMaybeLater: () => context.pop(),
            ),
          _Pane.form => _FormBody(
              ghin: _ghin,
              first: _first,
              last: _last,
              saving: _saving,
              onBack: _onFormBack,
              onSubmit: _submit,
            ),
          _Pane.pending => _PendingBody(
              ghin: _displayGhin(),
              nameLine: _displayNameLine(),
              isAppeal: _latest?['status']?.toString() == 'APPEAL',
              onBackToProfile: () {
                context.read<AuthSession>().bumpProfileRefresh();
                context.pop();
              },
            ),
          _Pane.success => _SuccessBody(
              onViewProfile: () {
                context.read<AuthSession>().bumpProfileRefresh();
                context.go(AppPaths.appProfile);
              },
              onHome: () => context.go(AppPaths.app),
            ),
          _Pane.rejected => _RejectedBody(
              onTryAgain: _tryAgainFromRejected,
              onSupport: () => context.push(AppPaths.support),
              onBackToProfile: () {
                context.read<AuthSession>().bumpProfileRefresh();
                context.pop();
              },
            ),
        },
      ),
    );
  }
}

// --- Intro (Get GHIN Verified + benefits + what you need) ---

class _IntroBody extends StatelessWidget {
  const _IntroBody({
    required this.error,
    required this.onBack,
    required this.onStart,
    required this.onMaybeLater,
  });

  final String? error;
  final VoidCallback onBack;
  final VoidCallback onStart;
  final VoidCallback onMaybeLater;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: onBack,
                color: CgColors.gray900,
              ),
            ],
          ),
          const Text(
            'Get GHIN Verified',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: CgColors.gray900, height: 1.2),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stand out with the blue verification badge',
            style: TextStyle(fontSize: 16, color: CgColors.gray600, height: 1.4),
          ),
          const SizedBox(height: 24),
          if (error != null) ...[
            Text(error!, style: const TextStyle(color: CgColors.destructive, fontSize: 14)),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: CgColors.blue50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(color: CgColors.blue600, shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_rounded, color: CgColors.white, size: 38),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Official GHIN Verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CgColors.gray900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verify your handicap index with your official GHIN number',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: CgColors.gray600, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'VERIFICATION BENEFITS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: CgColors.gray500,
            ),
          ),
          const SizedBox(height: 14),
          _benefitTile(
            bg: CgColors.green50,
            icon: Icons.check_circle_rounded,
            iconColor: CgColors.green700,
            title: 'Stand Out',
            body: 'Get the blue verified badge on your profile.',
          ),
          const SizedBox(height: 12),
          _benefitTile(
            bg: CgColors.blue50,
            icon: Icons.people_outline_rounded,
            iconColor: CgColors.blue600,
            title: 'Build Trust',
            body: 'Show others you\'re a legitimate golfer.',
          ),
          const SizedBox(height: 12),
          _benefitTile(
            bg: CgColors.purple50,
            icon: Icons.bolt_rounded,
            iconColor: CgColors.purple700,
            title: 'Get More Matches',
            body: 'Verified profiles get more attention in Discover and GHINder.',
          ),
          const SizedBox(height: 28),
          _infoCard(
            title: 'What you\'ll need',
            bullets: const [
              'Your GHIN number',
              'Name matching your GHIN account',
              'Verification typically takes 24–48 hours',
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: CgColors.blue600,
                foregroundColor: CgColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Start Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onMaybeLater,
            child: const Text('Maybe Later', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  static Widget _benefitTile({
    required Color bg,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CgColors.gray200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 14, color: CgColors.gray600, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _infoCard({required String title, required List<String> bullets}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CgColors.blue50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CgColors.blue600.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 20, color: CgColors.blue600),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: CgColors.gray900)),
            ],
          ),
          const SizedBox(height: 12),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: CgColors.blue600, fontWeight: FontWeight.w700)),
                  Expanded(child: Text(b, style: const TextStyle(fontSize: 14, color: CgColors.gray700, height: 1.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Form ---

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.ghin,
    required this.first,
    required this.last,
    required this.saving,
    required this.onBack,
    required this.onSubmit,
  });

  final TextEditingController ghin;
  final TextEditingController first;
  final TextEditingController last;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: onBack,
                color: CgColors.gray900,
              ),
            ],
          ),
          const Text(
            'Verify Your GHIN',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: CgColors.gray900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your GHIN information',
            style: TextStyle(fontSize: 15, color: CgColors.gray600),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CgColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CgColors.gray200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CgLabeledField(
                  label: 'GHIN Number',
                  child: CgTextField(
                    controller: ghin,
                    hint: 'e.g., 1234567',
                    keyboardType: TextInputType.text,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your GHIN number as shown on your card or app',
                  style: TextStyle(fontSize: 12, color: CgColors.gray500),
                ),
                const SizedBox(height: 20),
                CgLabeledField(
                  label: 'First Name',
                  child: CgTextField(controller: first, hint: 'As shown on GHIN'),
                ),
                const SizedBox(height: 20),
                CgLabeledField(
                  label: 'Last Name',
                  child: CgTextField(controller: last, hint: 'As shown on GHIN'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CgColors.yellow50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CgColors.yellow200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: CgColors.yellow700, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Important',
                      style: TextStyle(fontWeight: FontWeight.w700, color: CgColors.yellow800, fontSize: 15),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Your name must match exactly as it appears in the GHIN database. '
                  'Verification may be delayed or denied if the information doesn\'t match.',
                  style: TextStyle(fontSize: 14, color: CgColors.gray700, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'By submitting, you agree to our verification process and confirm that the information provided is accurate.',
            style: TextStyle(fontSize: 12, color: CgColors.gray500, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: saving ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: CgColors.blue600,
                foregroundColor: CgColors.white,
                disabledBackgroundColor: CgColors.gray300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(saving ? 'Submitting…' : 'Submit for Verification', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Pending ---

class _PendingBody extends StatelessWidget {
  const _PendingBody({
    required this.ghin,
    required this.nameLine,
    required this.isAppeal,
    required this.onBackToProfile,
  });

  final String ghin;
  final String nameLine;
  final bool isAppeal;
  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(color: CgColors.yellow100, shape: BoxShape.circle),
            child: const Icon(Icons.schedule_rounded, size: 44, color: CgColors.yellow700),
          ),
          const SizedBox(height: 20),
          Text(
            isAppeal ? 'Appeal received' : 'Verification Pending',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: CgColors.gray900),
          ),
          const SizedBox(height: 10),
          Text(
            isAppeal
                ? 'We\'re reviewing your appeal. This typically takes 24–48 hours.'
                : 'We\'re reviewing your GHIN information. This typically takes 24–48 hours.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: CgColors.gray600, height: 1.45),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CgColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CgColors.gray200),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Submitted Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 16),
                _kvRow('GHIN Number', ghin),
                const SizedBox(height: 12),
                _kvRow('Name', nameLine),
                const SizedBox(height: 12),
                _kvRow('Status', 'Under Review', valueColor: CgColors.yellow700),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                const Text('What happens next?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: CgColors.gray900)),
                const SizedBox(height: 12),
                _bullet('We\'ll verify your info against the GHIN database'),
                _bullet('You\'ll get a notification when it\'s complete'),
                _bullet('Your blue badge will appear automatically when approved'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          TextButton(onPressed: onBackToProfile, child: const Text('Back to Profile', style: TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  static Widget _kvRow(String k, String v, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(k, style: const TextStyle(color: CgColors.gray600, fontSize: 14)),
        ),
        Expanded(
          flex: 3,
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: valueColor ?? CgColors.gray900),
          ),
        ),
      ],
    );
  }

  static Widget _bullet(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: CgColors.blue600)),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 14, color: CgColors.gray700, height: 1.4))),
        ],
      ),
    );
  }
}

// --- Success ---

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.onViewProfile, required this.onHome});

  final VoidCallback onViewProfile;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(color: CgColors.blue600, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: CgColors.white, size: 52),
          ),
          const SizedBox(height: 24),
          const Text('You\'re Verified!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Your GHIN has been successfully verified',
            style: TextStyle(fontSize: 15, color: CgColors.gray600),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CgColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CgColors.gray200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: CgColors.blue600, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: CgColors.white, size: 16),
                      SizedBox(width: 6),
                      Text('GHIN Verified', style: TextStyle(color: CgColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'The blue verified badge is now visible on your profile.',
                  style: TextStyle(fontSize: 14, color: CgColors.gray600, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: CgColors.green50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CgColors.green100),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🎉  Congratulations!', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: CgColors.green800)),
                SizedBox(height: 8),
                Text(
                  'Verified profiles get more likes and matches. Start connecting with more golfers now!',
                  style: TextStyle(fontSize: 14, color: CgColors.green900, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onViewProfile,
              style: FilledButton.styleFrom(
                backgroundColor: CgColors.green700,
                foregroundColor: CgColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('View My Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onHome,
            child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// --- Rejected ---

class _RejectedBody extends StatelessWidget {
  const _RejectedBody({
    required this.onTryAgain,
    required this.onSupport,
    required this.onBackToProfile,
  });

  final VoidCallback onTryAgain;
  final VoidCallback onSupport;
  final VoidCallback onBackToProfile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: CgColors.red500.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: CgColors.red500, size: 44),
          ),
          const SizedBox(height: 20),
          const Text(
            'Verification Unsuccessful',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: CgColors.gray900),
          ),
          const SizedBox(height: 8),
          const Text(
            'We couldn\'t verify your GHIN information',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: CgColors.gray600),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CgColors.red400.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Common reasons:', style: TextStyle(fontWeight: FontWeight.w700, color: CgColors.red500.withValues(alpha: 0.95), fontSize: 15)),
                const SizedBox(height: 10),
                _rBullet('Name doesn\'t match GHIN database'),
                _rBullet('GHIN number is incorrect or inactive'),
                _rBullet('Typos in submitted information'),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                const Text('What you can do:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: CgColors.gray900)),
                const SizedBox(height: 10),
                _bBullet('Double-check your GHIN number'),
                _bBullet('Verify your name spelling matches exactly'),
                _bBullet('Contact your golf club if issues persist'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onTryAgain,
              style: FilledButton.styleFrom(
                backgroundColor: CgColors.blue600,
                foregroundColor: CgColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onSupport,
              style: OutlinedButton.styleFrom(
                foregroundColor: CgColors.gray900,
                side: const BorderSide(color: CgColors.gray300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Contact Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onBackToProfile, child: const Text('Back to Profile', style: TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  static Widget _rBullet(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: TextStyle(color: CgColors.red500.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
          Expanded(child: Text(t, style: TextStyle(fontSize: 14, color: CgColors.red500.withValues(alpha: 0.95), height: 1.4))),
        ],
      ),
    );
  }

  static Widget _bBullet(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: CgColors.blue600, fontWeight: FontWeight.w700)),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 14, color: CgColors.gray700, height: 1.4))),
        ],
      ),
    );
  }
}
