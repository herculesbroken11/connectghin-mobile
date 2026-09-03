import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/widgets/cg_outline_button.dart';
import '../../core/widgets/cg_primary_button.dart';

/// Shown when `GET /auth/me` reports the account is suspended or not ACTIVE.
/// The app router sends restricted users here instead of the main shell.
class AccountSuspendedScreen extends StatelessWidget {
  const AccountSuspendedScreen({super.key});

  static const _headingBlue = Color(0xFF001F3F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: CgColors.red50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: CgColors.red700, size: 40),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Account Suspended',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _headingBlue,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your account has been suspended and you cannot use Connectghin until access is restored.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray600),
            ),
            const SizedBox(height: 28),
            const Text(
              'What you can do',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: CgColors.gray900,
              ),
            ),
            const SizedBox(height: 12),
            _bullet(CgColors.green700,
                'Review our Terms of Service and community expectations'),
            const SizedBox(height: 10),
            _bullet(CgColors.green700,
                'Contact support if you believe this is a mistake'),
            const SizedBox(height: 10),
            _bullet(CgColors.green700,
                'Wait for our team to review your account status'),
            const SizedBox(height: 28),
            CgPrimaryButton(
              label: 'Contact Support',
              borderRadius: 12,
              onPressed: () => context.push(AppPaths.support),
            ),
            const SizedBox(height: 12),
            CgOutlineButton(
              label: 'View Terms of Service',
              onPressed: () => context.push(AppPaths.appTerms),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () async {
                  await context.read<AuthSession>().clear();
                  if (context.mounted) context.go(AppPaths.welcome);
                },
                child: const Text(
                  'Log out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CgColors.gray700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bullet(Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 15, height: 1.45, color: CgColors.gray700),
          ),
        ),
      ],
    );
  }
}
