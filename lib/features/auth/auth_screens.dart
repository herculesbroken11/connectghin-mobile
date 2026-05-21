import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';
import '../../core/widgets/cg_text_field.dart';
import '../../core/widgets/google_mark.dart';
import 'widgets/auth_multi_login_widgets.dart';

String _googleServerClientId() {
  const defined = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  if (defined.trim().isNotEmpty) return defined.trim();
  if (!dotenv.isInitialized) return '';
  return dotenv.env['GOOGLE_SERVER_CLIENT_ID']?.trim() ?? '';
}

Future<void>? _googleSignInInitialize;
String? _initializedGoogleServerClientId;

Future<void> _ensureGoogleSignInInitialized(String serverClientId) {
  if (_initializedGoogleServerClientId == serverClientId && _googleSignInInitialize != null) {
    return _googleSignInInitialize!;
  }
  _initializedGoogleServerClientId = serverClientId;
  _googleSignInInitialize = GoogleSignIn.instance.initialize(serverClientId: serverClientId);
  return _googleSignInInitialize!;
}

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

  bool get _canUseAppleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

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
      context.go(AppPaths.app);
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _googleBusy = true);
    try {
      final serverClientId = _googleServerClientId();
      if (serverClientId.isEmpty) {
        showUserMessageSnackBar(context, 'Google login is not configured for this build.');
        return;
      }
      final session = context.read<AuthSession>();
      final googleSignIn = GoogleSignIn.instance;
      await _ensureGoogleSignInInitialized(serverClientId);
      final account = await googleSignIn.authenticate();
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google sign-in did not return an id token');
      }
      final res = await session.authApi.loginWithGoogle(idToken: idToken);
      await session.setTokens(
        access: res['accessToken'] as String,
        refresh: res['refreshToken'] as String,
        signInMethod: 'google',
      );
      if (!mounted) return;
      context.go(AppPaths.app);
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
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
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Apple sign-in did not return an identity token');
      }
      final res = await session.authApi.loginWithApple(
        idToken: idToken,
        email: credential.email,
      );
      await session.setTokens(
        access: res['accessToken'] as String,
        refresh: res['refreshToken'] as String,
        signInMethod: 'apple',
      );
      if (!mounted) return;
      context.go(AppPaths.app);
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _appleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      backgroundColor: CgColors.green50,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CgResponsiveContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => context.go(AppPaths.welcome),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 22, color: CgColors.gray600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const CgAuthBrandMark(),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: wide ? 32 : 26,
                              fontWeight: FontWeight.w700,
                              color: CgColors.gray900,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your ConnectGHIN account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CgColors.gray600, height: 1.35),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Demo: john@demo.connectghin.com / Password123!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: CgColors.gray500.withValues(alpha: 0.95)),
                        ),
                      ],
                      const SizedBox(height: 28),
                      if (_canUseAppleSignIn) ...[
                        CgSocialSignInButton(
                          label: 'Continue with Apple',
                          busy: _appleBusy,
                          leading: const Icon(Icons.apple, size: 24, color: CgColors.gray900),
                          onPressed: _loginWithApple,
                        ),
                        const SizedBox(height: 12),
                      ],
                      CgSocialSignInButton(
                        label: 'Continue with Google',
                        busy: _googleBusy,
                        leading: const GoogleMark(),
                        onPressed: _loginWithGoogle,
                      ),
                      const SizedBox(height: 22),
                      const CgOrDivider(),
                      const SizedBox(height: 22),
                      Consumer<AuthSession>(
                        builder: (context, session, _) {
                          final n = session.authNotice;
                          if (n == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: CgColors.red50,
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline, color: CgColors.red700, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        n,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                          color: CgColors.gray900,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 20, color: CgColors.gray500),
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
                        ),
                      ),
                      const SizedBox(height: 18),
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
                            style: TextStyle(color: CgColors.green700, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                        child: CgTextField(
                          controller: _password,
                          hint: 'Enter your password',
                          obscure: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      CgPrimaryButton(
                        label: _busy ? 'Signing in…' : 'Sign In',
                        onPressed: _busy ? null : _submit,
                        borderRadius: 12,
                        minHeight: 52,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('New to ConnectGHIN? ', style: TextStyle(color: CgColors.gray600, fontSize: 14)),
                          GestureDetector(
                            onTap: () => context.push(AppPaths.register),
                            child: const Text(
                              'Create an account',
                              style: TextStyle(color: CgColors.green700, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const CgAuthTrustFooter(secureLabel: 'Secure Login', privateLabel: 'Privacy Protected'),
                      SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
  bool _busy = false;
  bool _googleBusy = false;
  bool _appleBusy = false;
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool get _canUseAppleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool get _passwordsMatch => _password.text == _confirmPassword.text;

  bool get _canSubmitEmail {
    if (!_agreedTerms || !_over18 || _busy) return false;
    if (_fullName.text.trim().length < 2) return false;
    if (_email.text.trim().length < 5) return false;
    if (_password.text.length < 8) return false;
    return _passwordsMatch;
  }

  Future<void> _submit() async {
    if (!_passwordsMatch) {
      showUserMessageSnackBar(context, 'Passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      final session = context.read<AuthSession>();
      final username = derivedUsernameFromFullName(_fullName.text, _email.text);
      final res = await session.authApi.register(
        email: _email.text.trim(),
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

  Future<void> _continueWithGoogle() async {
    setState(() => _googleBusy = true);
    try {
      final serverClientId = _googleServerClientId();
      if (serverClientId.isEmpty) {
        showUserMessageSnackBar(context, 'Google sign up is not configured for this build.');
        return;
      }
      final session = context.read<AuthSession>();
      final googleSignIn = GoogleSignIn.instance;
      await _ensureGoogleSignInInitialized(serverClientId);
      final account = await googleSignIn.authenticate();
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google sign-in did not return an id token');
      }
      final res = await session.authApi.loginWithGoogle(idToken: idToken);
      await session.setTokens(
        access: res['accessToken'] as String,
        refresh: res['refreshToken'] as String,
        signInMethod: 'google',
      );
      if (!mounted) return;
      context.go(AppPaths.onboardingBasic);
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
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
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Apple sign-in did not return an identity token');
      }
      final res = await session.authApi.loginWithApple(
        idToken: idToken,
        email: credential.email,
      );
      await session.setTokens(
        access: res['accessToken'] as String,
        refresh: res['refreshToken'] as String,
        signInMethod: 'apple',
      );
      if (!mounted) return;
      context.go(AppPaths.onboardingBasic);
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _appleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      backgroundColor: CgColors.green50,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CgResponsiveContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => context.go(AppPaths.welcome),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 22, color: CgColors.gray600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const CgAuthBrandMark(),
                      const SizedBox(height: 20),
                      Text(
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: wide ? 32 : 26,
                              fontWeight: FontWeight.w700,
                              color: CgColors.gray900,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join the premier golf network',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CgColors.gray600, height: 1.35),
                      ),
                      const SizedBox(height: 24),
                      if (_canUseAppleSignIn) ...[
                        CgSocialSignInButton(
                          label: 'Sign up with Apple',
                          busy: _appleBusy,
                          leading: const Icon(Icons.apple, size: 24, color: CgColors.gray900),
                          onPressed: _continueWithApple,
                        ),
                        const SizedBox(height: 12),
                      ],
                      CgSocialSignInButton(
                        label: 'Sign up with Google',
                        busy: _googleBusy,
                        leading: const GoogleMark(),
                        onPressed: _continueWithGoogle,
                      ),
                      const SizedBox(height: 22),
                      const CgOrDivider(label: 'or email'),
                      const SizedBox(height: 22),
                      CgLabeledField(
                        label: 'Full Name',
                        child: CgTextField(
                          controller: _fullName,
                          hint: 'John Smith',
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 18),
                      CgLabeledField(
                        label: 'Email',
                        child: CgTextField(
                          controller: _email,
                          hint: 'your.email@example.com',
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 18),
                      CgLabeledField(
                        label: 'Password',
                        child: CgTextField(
                          controller: _password,
                          hint: 'At least 8 characters',
                          obscure: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 18),
                      CgLabeledField(
                        label: 'Confirm Password',
                        child: CgTextField(
                          controller: _confirmPassword,
                          hint: 'Re-enter password',
                          obscure: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_confirmPassword.text.isNotEmpty && !_passwordsMatch) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Passwords must match',
                          style: TextStyle(color: CgColors.red700, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _agreedTerms,
                              activeColor: CgColors.green700,
                              onChanged: (v) => setState(() => _agreedTerms = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  'I agree to the ',
                                  style: TextStyle(fontSize: 14, color: CgColors.gray600, height: 1.45),
                                ),
                                GestureDetector(
                                  onTap: () => context.push(AppPaths.legalTerms),
                                  child: const Text(
                                    'Terms',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: CgColors.green700,
                                      fontWeight: FontWeight.w600,
                                      height: 1.45,
                                      decoration: TextDecoration.underline,
                                      decorationColor: CgColors.green700,
                                    ),
                                  ),
                                ),
                                const Text(
                                  ' and ',
                                  style: TextStyle(fontSize: 14, color: CgColors.gray600, height: 1.45),
                                ),
                                GestureDetector(
                                  onTap: () => context.push(AppPaths.legalPrivacy),
                                  child: const Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: CgColors.green700,
                                      fontWeight: FontWeight.w600,
                                      height: 1.45,
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
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _over18,
                              activeColor: CgColors.green700,
                              onChanged: (v) => setState(() => _over18 = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'I am 18 years or older',
                              style: TextStyle(fontSize: 14, color: CgColors.gray600, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      CgPrimaryButton(
                        label: _busy ? 'Creating…' : 'Create Account',
                        onPressed: _canSubmitEmail ? _submit : null,
                        borderRadius: 12,
                        minHeight: 52,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have an account? ', style: TextStyle(color: CgColors.gray600, fontSize: 14)),
                          GestureDetector(
                            onTap: () => context.push(AppPaths.login),
                            child: const Text(
                              'Sign in',
                              style: TextStyle(color: CgColors.green700, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const CgAuthTrustFooter(),
                      SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
