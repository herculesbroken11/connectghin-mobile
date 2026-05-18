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
///
/// Reason / end date / reference ID are placeholders until the API exposes them.
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
                child: const Icon(Icons.warning_amber_rounded, color: CgColors.red700, size: 40),
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
              'Your account has been temporarily suspended due to a violation of our Community Guidelines.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray600),
            ),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: CgColors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: CgColors.gray200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _detailRow(
                    'Reason',
                    'Multiple reports of inappropriate behavior',
                  ),
                  const Divider(height: 1, color: CgColors.gray200),
                  _detailRow(
                    'Suspension period',
                    '7 days (ends April 15, 2026)',
                  ),
                  const Divider(height: 1, color: CgColors.gray200),
                  _detailRow(
                    'Reference ID',
                    'SUSP-2026-04-08-1234',
                  ),
                ],
              ),
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
            _bullet(CgColors.green700, 'Review our Community Guidelines to understand our policies'),
            const SizedBox(height: 10),
            _bullet(CgColors.green700, 'If you believe this is a mistake, contact our support team'),
            const SizedBox(height: 10),
            _bullet(CgColors.green700, 'Your account will be automatically restored after the suspension period'),
            const SizedBox(height: 28),
            CgPrimaryButton(
              label: 'Contact Support',
              borderRadius: 12,
              onPressed: () => context.push(AppPaths.support),
            ),
            const SizedBox(height: 12),
            CgOutlineButton(
              label: 'View Community Guidelines',
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

  static Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CgColors.gray500,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _headingBlue,
              height: 1.35,
            ),
          ),
        ],
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
            style: const TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray700),
          ),
        ),
      ],
    );
  }
}
