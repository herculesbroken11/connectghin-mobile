import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/layout/cg_fit_height_body.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_text_field.dart';
import '../../core/widgets/google_mark.dart';
import 'apple_sign_in_helper.dart';
import 'google_sign_in_helper.dart';
import 'register_password_screen.dart';
import 'widgets/auth_multi_login_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.magicToken});

  final String? magicToken;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _googleBusy = false;
  bool _appleBusy = false;
  String? _googleError;

  bool get _canUseAppleSignIn => AppleSignInHelper.isSupported;

  @override
  void initState() {
    super.initState();
    final token = widget.magicToken?.trim();
    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showUserMessageSnackBar(context, 'Magic link login has been removed. Please sign in directly.');
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final session = context.read<AuthSession>();
      final res = await session.authApi.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      await session.setTokens(
        access: res['accessToken'] as String,
        refresh: res['refreshToken'] as String,
        signInMethod: 'email',
      );
      if (!mounted) return;
      if (!session.isLoggedIn) {
        context.go(AppPaths.login);
        return;
      }
      context.go(session.postAuthLocation);
    } catch (e) {
      if (!isSignInCancelledError(e) && mounted) showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _googleBusy = true;
      _googleError = null;
    });
    try {
      final idToken = await GoogleSignInHelper.obtainIdToken();
      final session = context.read<AuthSession>();
      final res = await session.authApi.loginWithGoogle(idToken: idToken);
      await session.setTokens(
        access: res['accessToken'] as String,
        refresh: res['refreshToken'] as String,
        signInMethod: 'google',
      );
      if (!mounted) return;
      context.go(session.postAuthLocation);
    } catch (e) {
      if (!mounted || isSignInCancelledError(e)) return;
      setState(() => _googleError = messageFromGoogleSignInError(e));
      showUserMessageSnackBar(context, messageFromGoogleSignInError(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _loginWithApple() async {
    if (!_canUseAppleSignIn) {
      showUserMessageSnackBar(context, 'Apple login is available on iPhone and iPad.');
      return;
    }
    setState(() => _appleBusy = true);
    try {
      final session = context.read<AuthSession>();
      final apple = await AppleSignInHelper.obtainCredential();
      final res = await session.authApi.loginWithApple(
        idToken: apple.identityToken,
        email: apple.email,
        fullName: apple.fullName,
        nonce: apple.rawNonce,
      );
      await session.setTokens(
        access: res['accessToken'] as String,
        refresh: res['refreshToken'] as String,
        signInMethod: 'apple',
      );
      if (!mounted) return;
      context.go(session.postAuthLocation);
    } catch (e) {
      if (!isSignInCancelledError(e) && mounted) {
        showUserMessageSnackBar(context, messageFromAppleSignInError(e));
      }
    } finally {
      if (mounted) setState(() => _appleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final short = cgIsShortScreen(context);
    final gap = (double v) => cgCompactGap(context, v);
    final socialH = short ? 46.0 : 50.0;

    return Scaffold(
      backgroundColor: CgColors.cream,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          CgAuthGreenHero(
            compact: short,
            onBack: () => context.go(AppPaths.welcome),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: CgColors.cream,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(24, short ? 18 : 24, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight - 8),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Welcome back',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.fraunces(
                                    fontSize: short ? 26 : 30,
                                    fontWeight: FontWeight.w600,
                                    color: CgColors.green900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: gap(6)),
                                Text(
                                  'Sign in to your Connectghin account',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: CgColors.gray600,
                                    height: 1.25,
                                    fontSize: short ? 13 : 14,
                                  ),
                                ),
                                if (kDebugMode) ...[
                                  SizedBox(height: gap(6)),
                                  Text(
                                    'Demo: john@demo.connectghin.com / Password123!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, color: CgColors.gray500.withValues(alpha: 0.95)),
                                  ),
                                ],
                                SizedBox(height: gap(18)),
                                if (_canUseAppleSignIn) ...[
                                  CgSocialSignInButton(
                                    label: 'Continue with Apple',
                                    busy: _appleBusy,
                                    minHeight: socialH,
                                    leading: const Icon(Icons.apple, size: 22, color: CgColors.gray900),
                                    onPressed: _loginWithApple,
                                  ),
                                  SizedBox(height: gap(10)),
                                ],
                                CgSocialSignInButton(
                                  label: 'Continue with Google',
                                  busy: _googleBusy,
                                  minHeight: socialH,
                                  leading: const GoogleMark(),
                                  onPressed: _loginWithGoogle,
                                ),
                                if (_googleError != null) ...[
                                  SizedBox(height: gap(10)),
                                  CgAuthInlineError(
                                    message: _googleError!,
                                    onDismiss: () => setState(() => _googleError = null),
                                  ),
                                ],
                                SizedBox(height: gap(16)),
                                const CgOrDivider(),
                                SizedBox(height: gap(16)),
                                Consumer<AuthSession>(
                                  builder: (context, session, _) {
                                    final n = session.authNotice;
                                    if (n == null) return const SizedBox.shrink();
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: gap(10)),
                                      child: Material(
                                        color: CgColors.red50,
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.info_outline, color: CgColors.red700, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  n,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    height: 1.35,
                                                    color: CgColors.gray900,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 18, color: CgColors.gray500),
                                                onPressed: session.consumeAuthNotice,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                CgLabeledField(
                                  label: 'Email',
                                  child: CgTextField(
                                    controller: _email,
                                    hint: 'your.email@example.com',
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: Icons.mail_outline_rounded,
                                  ),
                                ),
                                SizedBox(height: gap(14)),
                                CgLabeledField(
                                  label: 'Password',
                                  trailing: TextButton(
                                    onPressed: () => context.push(AppPaths.forgotPassword),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Forgot password?',
                                      style: TextStyle(color: CgColors.green700, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  child: CgTextField(
                                    controller: _password,
                                    hint: 'Enter your password',
                                    obscure: true,
                                    showVisibilityToggle: true,
                                    prefixIcon: Icons.lock_outline_rounded,
                                  ),
                                ),
                                SizedBox(height: gap(18)),
                                CgPrimaryButton(
                                  label: _busy ? 'Signing in…' : 'Sign In',
                                  onPressed: _busy ? null : _submit,
                                  borderRadius: 14,
                                  minHeight: short ? 48 : 52,
                                  showTrailingArrow: !_busy,
                                ),
                                SizedBox(height: gap(14)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'New to Connectghin? ',
                                      style: TextStyle(color: CgColors.gray600, fontSize: short ? 13 : 14),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.push(AppPaths.register),
                                      child: const Text(
                                        'Create an account',
                                        style: TextStyle(color: CgColors.green700, fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                SizedBox(height: gap(12)),
                                const CgAuthTrustFooter(
                                  secureLabel: 'Secure Login',
                                  privateLabel: 'Privacy Protected',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _agreedTerms = false;
  bool _over18 = false;
  bool _googleBusy = false;
  bool _appleBusy = false;
  String? _googleError;
  final _fullName = TextEditingController();
  final _email = TextEditingController();

  bool get _canUseAppleSignIn => AppleSignInHelper.isSupported;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _canContinue {
    if (!_agreedTerms || !_over18) return false;
    if (_fullName.text.trim().length < 2) return false;
    if (_email.text.trim().length < 5) return false;
    return true;
  }

  void _continueToPassword() {
    if (!_canContinue) return;
    context.push(
      AppPaths.registerPassword,
      extra: RegisterPasswordArgs(
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
      ),
    );
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _googleBusy = true;
      _googleError = null;
    });
    try {
      final idToken = await GoogleSignInHelper.obtainIdToken();
      final session = context.read<AuthSession>();
      final res = await session.authApi.loginWithGoogle(idToken: idToken);
      await session.setTokens(
        access: res['accessToken'] as String,
        refresh: res['refreshToken'] as String,
        signInMethod: 'google',
      );
      if (!mounted) return;
      context.go(session.postAuthLocation);
    } catch (e) {
      if (!mounted || isSignInCancelledError(e)) return;
      setState(() => _googleError = messageFromGoogleSignInError(e));
      showUserMessageSnackBar(context, messageFromGoogleSignInError(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _continueWithApple() async {
    if (!_canUseAppleSignIn) {
      showUserMessageSnackBar(context, 'Apple sign up is available on iPhone and iPad.');
      return;
    }
    setState(() => _appleBusy = true);
    try {
      final session = context.read<AuthSession>();
      final apple = await AppleSignInHelper.obtainCredential();
      final res = await session.authApi.loginWithApple(
        idToken: apple.identityToken,
        email: apple.email,
        fullName: apple.fullName,
        nonce: apple.rawNonce,
      );
      await session.setTokens(
        access: res['accessToken'] as String,
        refresh: res['refreshToken'] as String,
        signInMethod: 'apple',
      );
      if (!mounted) return;
      context.go(session.postAuthLocation);
    } catch (e) {
      if (!isSignInCancelledError(e) && mounted) {
        showUserMessageSnackBar(context, messageFromAppleSignInError(e));
      }
    } finally {
      if (mounted) setState(() => _appleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final short = cgIsShortScreen(context);
    final gap = (double v) => cgCompactGap(context, v);
    final socialH = short ? 46.0 : 50.0;
    final finePrint = short ? 12.5 : 13.5;

    return Scaffold(
      backgroundColor: CgColors.cream,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          CgAuthGreenHero(
            compact: short,
            onBack: () => context.go(AppPaths.welcome),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: CgColors.cream,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(24, short ? 18 : 24, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight - 8),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Create Account',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.fraunces(
                                    fontSize: short ? 26 : 30,
                                    fontWeight: FontWeight.w600,
                                    color: CgColors.green900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: gap(6)),
                                Text(
                                  'Join Connectghin — the premier golf network',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: CgColors.gray600,
                                    height: 1.25,
                                    fontSize: short ? 13 : 14,
                                  ),
                                ),
                                SizedBox(height: gap(18)),
                                if (_canUseAppleSignIn) ...[
                                  CgSocialSignInButton(
                                    label: 'Sign up with Apple',
                                    busy: _appleBusy,
                                    minHeight: socialH,
                                    leading: const Icon(Icons.apple, size: 22, color: CgColors.gray900),
                                    onPressed: _continueWithApple,
                                  ),
                                  SizedBox(height: gap(10)),
                                ],
                                CgSocialSignInButton(
                                  label: 'Sign up with Google',
                                  busy: _googleBusy,
                                  minHeight: socialH,
                                  leading: const GoogleMark(),
                                  onPressed: _continueWithGoogle,
                                ),
                                if (_googleError != null) ...[
                                  SizedBox(height: gap(10)),
                                  CgAuthInlineError(
                                    message: _googleError!,
                                    onDismiss: () => setState(() => _googleError = null),
                                  ),
                                ],
                                SizedBox(height: gap(16)),
                                const CgOrDivider(label: 'or email'),
                                SizedBox(height: gap(16)),
                                CgLabeledField(
                                  label: 'Full Name',
                                  child: CgTextField(
                                    controller: _fullName,
                                    hint: 'John Smith',
                                    textCapitalization: TextCapitalization.words,
                                    prefixIcon: Icons.person_outline_rounded,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                SizedBox(height: gap(12)),
                                CgLabeledField(
                                  label: 'Email',
                                  child: CgTextField(
                                    controller: _email,
                                    hint: 'your.email@example.com',
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: Icons.mail_outline_rounded,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                SizedBox(height: gap(14)),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: Checkbox(
                                        value: _agreedTerms,
                                        activeColor: CgColors.green700,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (v) => setState(() => _agreedTerms = v ?? false),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            'I agree to the ',
                                            style: TextStyle(fontSize: finePrint, color: CgColors.gray600, height: 1.3),
                                          ),
                                          GestureDetector(
                                            onTap: () => context.push(AppPaths.legalTerms),
                                            child: Text(
                                              'Terms',
                                              style: TextStyle(
                                                fontSize: finePrint,
                                                color: CgColors.green700,
                                                fontWeight: FontWeight.w600,
                                                height: 1.3,
                                                decoration: TextDecoration.underline,
                                                decorationColor: CgColors.green700,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            ' and ',
                                            style: TextStyle(fontSize: finePrint, color: CgColors.gray600, height: 1.3),
                                          ),
                                          GestureDetector(
                                            onTap: () => context.push(AppPaths.legalPrivacy),
                                            child: Text(
                                              'Privacy Policy',
                                              style: TextStyle(
                                                fontSize: finePrint,
                                                color: CgColors.green700,
                                                fontWeight: FontWeight.w600,
                                                height: 1.3,
                                                decoration: TextDecoration.underline,
                                                decorationColor: CgColors.green700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: gap(8)),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: Checkbox(
                                        value: _over18,
                                        activeColor: CgColors.green700,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (v) => setState(() => _over18 = v ?? false),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'I am 18 years or older',
                                        style: TextStyle(fontSize: finePrint, color: CgColors.gray600, height: 1.3),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: gap(18)),
                                CgPrimaryButton(
                                  label: 'Continue',
                                  onPressed: _canContinue ? _continueToPassword : null,
                                  borderRadius: 14,
                                  minHeight: short ? 48 : 52,
                                  showTrailingArrow: _canContinue,
                                ),
                                SizedBox(height: gap(14)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account? ',
                                      style: TextStyle(color: CgColors.gray600, fontSize: finePrint),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.push(AppPaths.login),
                                      child: Text(
                                        'Sign in',
                                        style: TextStyle(
                                          color: CgColors.green700,
                                          fontWeight: FontWeight.w700,
                                          fontSize: finePrint,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                SizedBox(height: gap(12)),
                                const CgAuthTrustFooter(),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
