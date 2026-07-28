import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_text_field.dart';
import '../misc/data/account_api.dart';

// --- Change Password (GHINder mock) ---

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _newPw = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _current.addListener(_onFieldChanged);
    _newPw.addListener(_onFieldChanged);
    _confirm.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _current.dispose();
    _newPw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _newOk => _newPw.text.length >= 8;
  bool get _confirmOk => _confirm.text.isNotEmpty && _newPw.text == _confirm.text;
  bool get _canSubmit =>
      !_saving &&
      !_success &&
      _current.text.isNotEmpty &&
      _newOk &&
      _confirmOk;

  bool get _showConfirmMismatch =>
      _confirm.text.isNotEmpty && _newPw.text.isNotEmpty && _newPw.text != _confirm.text;

  Future<void> _update() async {
    if (!_canSubmit) return;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() => _saving = true);
    try {
      final res = await AccountApi(session.apiClient).changePassword(
        accessToken: t,
        currentPassword: _current.text,
        newPassword: _newPw.text,
      );
      final access = res['accessToken'] as String?;
      final refresh = res['refreshToken'] as String?;
      if (access != null &&
          access.isNotEmpty &&
          refresh != null &&
          refresh.isNotEmpty) {
        await session.setTokens(access: access, refresh: refresh);
      } else {
        await session.forceSignOut(
          notice: 'Password updated. Please sign in with your new password.',
        );
      }
      if (!mounted) return;
      setState(() {
        _success = true;
        _saving = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showApiErrorSnackBar(context, e);
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
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          const Text(
            'Change Password',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: CgColors.gray900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Update your password to keep your account secure',
            style: TextStyle(fontSize: 15, height: 1.35, color: CgColors.gray600),
          ),
          const SizedBox(height: 28),
          CgLabeledField(
            label: 'Current Password',
            child: CgTextField(
              controller: _current,
              obscure: true,
              hint: 'Enter current password',
            ),
          ),
          const SizedBox(height: 20),
          CgLabeledField(
            label: 'New Password',
            child: CgTextField(
              controller: _newPw,
              obscure: true,
              hint: 'Enter new password',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Must be at least 8 characters',
            style: TextStyle(
              fontSize: 13,
              color: _newPw.text.isNotEmpty && !_newOk ? CgColors.destructive : CgColors.gray500,
            ),
          ),
          const SizedBox(height: 20),
          CgLabeledField(
            label: 'Confirm New Password',
            child: CgTextField(
              controller: _confirm,
              obscure: true,
              hint: 'Re-enter new password',
            ),
          ),
          if (_showConfirmMismatch) ...[
            const SizedBox(height: 6),
            const Text(
              'Passwords do not match',
              style: TextStyle(fontSize: 13, color: CgColors.destructive),
            ),
          ],
          if (_success) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CgColors.green50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CgColors.green100),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: CgColors.green700, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password updated successfully!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CgColors.green800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Redirecting to settings…',
                          style: TextStyle(fontSize: 14, color: CgColors.green700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          CgPrimaryButton(
            label: _saving ? 'Updating…' : 'Update Password',
            borderRadius: 12,
            onPressed: _canSubmit ? _update : null,
          ),
          const SizedBox(height: 28),
          _PasswordTipsCard(),
        ],
      ),
    );
  }
}

class _PasswordTipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const tips = [
      'Use a mix of letters, numbers, and symbols',
      'Avoid common words or personal information',
      "Don't reuse passwords from other sites",
      'Change your password regularly',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CgColors.blue50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CgColors.blue50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password Tips:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CgColors.blue700,
            ),
          ),
          const SizedBox(height: 10),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: CgColors.blue700, height: 1.4)),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(fontSize: 14, height: 1.45, color: CgColors.blue700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Change Username (GHINder mock) ---

class ChangeUsernameScreen extends StatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final _username = TextEditingController();
  String? _initialUsername;
  bool _loadingMe = true;
  bool _saving = false;
  bool _success = false;
  bool _checking = false;
  bool? _serverAvailable;
  Timer? _debounce;

  static final _usernameRe = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

  @override
  void initState() {
    super.initState();
    _username.addListener(_onUsernameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMe());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) {
      if (mounted) setState(() => _loadingMe = false);
      return;
    }
    try {
      final me = await session.authApi.me(t);
      final u = me['username'] as String?;
      if (!mounted) return;
      setState(() {
        _initialUsername = u;
        if (u != null) {
          _username.text = u;
        }
        _loadingMe = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMe = false);
    }
  }

  void _onUsernameChanged() {
    _debounce?.cancel();
    final v = _username.text.trim();
    if (v.isEmpty) {
      setState(() {
        _serverAvailable = null;
        _checking = false;
      });
      return;
    }
    setState(() {
      _serverAvailable = null;
    });
    if (!_usernameRe.hasMatch(v)) {
      return;
    }
    if (v.toLowerCase() == (_initialUsername ?? '').toLowerCase()) {
      setState(() => _serverAvailable = true);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), _runAvailabilityCheck);
  }

  Future<void> _runAvailabilityCheck() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    final v = _username.text.trim();
    if (t == null || !_usernameRe.hasMatch(v)) return;
    if (v.toLowerCase() == (_initialUsername ?? '').toLowerCase()) {
      if (mounted) setState(() => _serverAvailable = true);
      return;
    }
    if (mounted) setState(() => _checking = true);
    try {
      final res = await AccountApi(session.apiClient).checkUsernameAvailable(
        accessToken: t,
        username: v,
      );
      final ok = res['available'] == true;
      if (mounted) {
        setState(() {
          _serverAvailable = ok;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverAvailable = null;
          _checking = false;
        });
      }
    }
  }

  bool get _formatOk => _usernameRe.hasMatch(_username.text.trim());
  bool get _unchanged =>
      _username.text.trim().toLowerCase() == (_initialUsername ?? '').toLowerCase();
  bool get _canSubmit =>
      !_saving &&
      !_success &&
      !_loadingMe &&
      _formatOk &&
      !_unchanged &&
      _serverAvailable == true &&
      !_checking;

  Future<void> _save() async {
    if (!_canSubmit) return;
    final v = _username.text.trim();
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() => _saving = true);
    try {
      await AccountApi(session.apiClient).updateUsername(accessToken: t, username: v);
      if (!mounted) return;
      session.bumpProfileRefresh();
      setState(() {
        _success = true;
        _saving = false;
        _initialUsername = v;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showApiErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMe) {
      return const Scaffold(
        backgroundColor: CgColors.white,
        body: Center(child: CircularProgressIndicator(color: CgColors.green700)),
      );
    }

    final v = _username.text.trim();
    final showFormatHint = v.isNotEmpty && !_formatOk;
    final showAvailable =
        _formatOk && !_unchanged && _serverAvailable == true && !_checking;
    final showTaken = _formatOk && !_unchanged && _serverAvailable == false && !_checking;

    return Scaffold(
      backgroundColor: CgColors.white,
      appBar: AppBar(
        backgroundColor: CgColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: CgColors.gray900),
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          const Text(
            'Change Username',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: CgColors.gray900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a unique username for your profile',
            style: TextStyle(fontSize: 15, height: 1.35, color: CgColors.gray600),
          ),
          const SizedBox(height: 28),
          CgLabeledField(
            label: 'Username',
            child: TextField(
              controller: _username,
              style: const TextStyle(fontSize: 16, color: CgColors.gray900),
              decoration: InputDecoration(
                hintText: 'your_username',
                hintStyle: const TextStyle(color: CgColors.gray400),
                filled: true,
                fillColor: CgColors.inputBg,
                prefixText: '@ ',
                prefixStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CgColors.gray700,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_checking && _formatOk && !_unchanged)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CgColors.green700),
                  ),
                  SizedBox(width: 10),
                  Text('Checking availability…', style: TextStyle(fontSize: 13, color: CgColors.gray600)),
                ],
              ),
            ),
          if (showAvailable)
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: CgColors.green700, size: 20),
                SizedBox(width: 8),
                Text(
                  'Username is available.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CgColors.green700),
                ),
              ],
            ),
          if (showTaken)
            const Row(
              children: [
                Icon(Icons.cancel_rounded, color: CgColors.destructive, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This username is already taken.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CgColors.destructive),
                  ),
                ),
              ],
            ),
          if (showFormatHint)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Use 3–30 characters: letters, numbers, and underscores only.',
                style: TextStyle(fontSize: 13, color: CgColors.destructive),
              ),
            ),
          if (!showFormatHint)
            Padding(
              padding: EdgeInsets.only(top: showAvailable || showTaken || _checking ? 8 : 0),
              child: const Text(
                'Must be 3–30 characters. Letters, numbers, and underscores only.',
                style: TextStyle(fontSize: 13, color: CgColors.blue700),
              ),
            ),
          if (_success) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CgColors.green50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CgColors.green100),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: CgColors.green700, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Username updated successfully!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CgColors.green800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Redirecting to settings…',
                          style: TextStyle(fontSize: 14, color: CgColors.green700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          CgPrimaryButton(
            label: _saving ? 'Updating…' : 'Update Username',
            borderRadius: 12,
            onPressed: _canSubmit ? _save : null,
          ),
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
                    text: 'Important: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        'Changing your username will update how other golfers find and mention you. Your old username will become available for others to use.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
