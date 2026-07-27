import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/layout/cg_fit_height_body.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_app_logo.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';
import '../../core/widgets/cg_text_field.dart';
import 'widgets/auth_multi_login_widgets.dart';

/// Carries step-1 register fields into the password step.
class RegisterPasswordArgs {
  const RegisterPasswordArgs({
    required this.fullName,
    required this.email,
  });

  final String fullName;
  final String email;
}

class RegisterPasswordScreen extends StatefulWidget {
  const RegisterPasswordScreen({super.key, required this.args});

  final RegisterPasswordArgs args;

  @override
  State<RegisterPasswordScreen> createState() => _RegisterPasswordScreenState();
}

class _RegisterPasswordScreenState extends State<RegisterPasswordScreen> {
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool get _passwordsMatch => _password.text == _confirmPassword.text;

  bool get _canSubmit =>
      !_busy && _password.text.length >= 8 && _passwordsMatch;

  Future<void> _submit() async {
    if (!_passwordsMatch) {
      showUserMessageSnackBar(context, 'Passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      final session = context.read<AuthSession>();
      final username = derivedUsernameFromFullName(widget.args.fullName, widget.args.email);
      final res = await session.authApi.register(
        email: widget.args.email.trim(),
        username: username,
        password: _password.text,
      );
      await session.setTokens(
        access: res['accessToken'] as String,
        refresh: res['refreshToken'] as String,
        signInMethod: 'email',
      );
      if (mounted) context.push(AppPaths.onboardingBasic);
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final short = cgIsShortScreen(context);
    final gap = (double v) => cgCompactGap(context, v);
    return Scaffold(
      backgroundColor: CgColors.green50,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: CgFitHeightBody(
          child: CgResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: CgColors.gray600),
                  ),
                ),
                SizedBox(height: gap(4)),
                CgAuthBrandMark(
                  size: cgAuthLogoHeight(context),
                  variant: CgAppLogoVariant.full,
                  plate: true,
                ),
                SizedBox(height: gap(12)),
                Text(
                  'Create a password',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: short ? 22 : 24,
                        fontWeight: FontWeight.w700,
                        color: CgColors.gray900,
                      ),
                ),
                SizedBox(height: gap(6)),
                Text(
                  widget.args.email.trim(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: short ? 13 : 14, color: CgColors.gray600),
                ),
                SizedBox(height: gap(16)),
                CgLabeledField(
                  label: 'Password',
                  child: CgTextField(
                    controller: _password,
                    hint: 'At least 8 characters',
                    obscure: true,
                    showVisibilityToggle: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(height: gap(12)),
                CgLabeledField(
                  label: 'Confirm password',
                  child: CgTextField(
                    controller: _confirmPassword,
                    hint: 'Re-enter password',
                    obscure: true,
                    showVisibilityToggle: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_confirmPassword.text.isNotEmpty && !_passwordsMatch) ...[
                  SizedBox(height: gap(6)),
                  const Text(
                    'Passwords must match',
                    style: TextStyle(color: CgColors.red700, fontSize: 13),
                  ),
                ],
                SizedBox(height: gap(16)),
                CgPrimaryButton(
                  label: _busy ? 'Creating…' : 'Create Account',
                  onPressed: _canSubmit ? _submit : null,
                  borderRadius: 12,
                  minHeight: short ? 46 : 50,
                ),
                SizedBox(height: gap(8)),
                const CgAuthTrustFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
