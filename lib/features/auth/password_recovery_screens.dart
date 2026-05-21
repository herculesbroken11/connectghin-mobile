import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/widgets/cg_outline_button.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_text_field.dart';

/// Forgot password → [ForgotPasswordSentScreen] → email link → [ResetPasswordScreen] → [ResetPasswordSuccessScreen].
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      showUserMessageSnackBar(context, 'Enter your email address.');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthSession>().authApi.forgotPassword(email: email);
      if (!mounted) return;
      context.push(AppPaths.forgotPasswordSent, extra: email);
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CgResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.go(AppPaths.login),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: CgColors.gray700),
                  label: const Text(
                    'Back to Login',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CgColors.gray700),
                  ),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: CgColors.gray700,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: CgColors.green50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mail_outline, size: 40, color: CgColors.green700),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Forgot Password?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        color: CgColors.gray900,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "No worries! Enter your email and we'll send you reset instructions.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray600),
                ),
                const SizedBox(height: 32),
                CgLabeledField(
                  label: 'Email Address',
                  child: CgTextField(
                    controller: _email,
                    hint: 'your.email@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(height: 28),
                CgPrimaryButton(
                  label: _busy ? 'Sending…' : 'Send Reset Link',
                  onPressed: _busy ? null : _send,
                  borderRadius: 12,
                ),
                const SizedBox(height: 28),
                Text.rich(
                  TextSpan(
                    text: 'Remember your password? ',
                    style: const TextStyle(color: CgColors.gray600, fontSize: 15),
                    children: [
                      TextSpan(
                        text: 'Sign In',
                        style: const TextStyle(
                          color: CgColors.green700,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = () => context.go(AppPaths.login),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordSentScreen extends StatelessWidget {
  const ForgotPasswordSentScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CgResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 1),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: CgColors.green50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline, size: 48, color: CgColors.green700),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Check Your Email',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: CgColors.gray900,
                      ),
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray600),
                    children: [
                      const TextSpan(text: "We've sent password reset instructions to "),
                      TextSpan(
                        text: email.isEmpty ? 'your email' : email,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: CgColors.gray900),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Didn't receive the email? Check your spam folder or try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: CgColors.gray500),
                ),
                const Spacer(flex: 2),
                CgOutlineButton(
                  label: 'Try Another Email',
                  onPressed: () => context.go(AppPaths.forgotPassword),
                ),
                const SizedBox(height: 12),
                CgPrimaryButton(
                  label: 'Back to Login',
                  borderRadius: 12,
                  onPressed: () => context.go(AppPaths.login),
                ),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.resetToken});

  final String? resetToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = widget.resetToken?.trim();
    if (token == null || token.isEmpty) {
      showUserMessageSnackBar(
        context,
        'Invalid or missing reset link. Request a new email from Forgot Password.',
      );
      return;
    }
    final p = _password.text;
    final c = _confirm.text;
    if (p.length < 8) {
      showUserMessageSnackBar(context, 'Password must be at least 8 characters.');
      return;
    }
    if (p != c) {
      showUserMessageSnackBar(context, 'Passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthSession>().authApi.resetPassword(token: token, newPassword: p);
      if (!mounted) return;
      context.go(AppPaths.resetPasswordSuccess);
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CgResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: CgColors.gray700),
                    onPressed: () => context.go(AppPaths.login),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: CgColors.green50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, size: 40, color: CgColors.green700),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Create New Password',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: CgColors.gray900,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your new password must be different from previously used passwords.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray600),
                ),
                const SizedBox(height: 28),
                CgLabeledField(
                  label: 'New Password',
                  child: CgTextField(
                    controller: _password,
                    hint: 'Enter new password',
                    obscure: true,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Must be at least 8 characters',
                  style: TextStyle(fontSize: 13, color: CgColors.gray500),
                ),
                const SizedBox(height: 20),
                CgLabeledField(
                  label: 'Confirm Password',
                  child: CgTextField(
                    controller: _confirm,
                    hint: 'Re-enter new password',
                    obscure: true,
                  ),
                ),
                const SizedBox(height: 24),
                CgPrimaryButton(
                  label: _busy ? 'Resetting…' : 'Reset Password',
                  onPressed: _busy ? null : _submit,
                  borderRadius: 12,
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CgColors.blue50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Password must contain:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CgColors.blue700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _reqRow('At least 8 characters'),
                      _reqRow('Mix of letters and numbers recommended'),
                    ],
                  ),
                ),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _reqRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: CgColors.blue600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.35, color: CgColors.gray700),
            ),
          ),
        ],
      ),
    );
  }
}

class ResetPasswordSuccessScreen extends StatelessWidget {
  const ResetPasswordSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CgResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 1),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      color: CgColors.green700,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 40, color: CgColors.white),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Password Reset Successful!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: CgColors.gray900,
                      ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your password has been successfully reset. You can now log in with your new password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray600),
                ),
                const Spacer(flex: 2),
                CgPrimaryButton(
                  label: 'Continue to Login',
                  borderRadius: 12,
                  onPressed: () => context.go(AppPaths.login),
                ),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
