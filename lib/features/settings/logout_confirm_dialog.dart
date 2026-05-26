import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';

/// Log-out confirmation over the current screen (light dim, not a black full-screen route).
class LogoutConfirmDialog {
  LogoutConfirmDialog._();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: CgColors.gray900.withValues(alpha: 0.32),
      builder: (dialogContext) => const _LogoutConfirmDialogBody(),
    );
  }
}

class _LogoutConfirmDialogBody extends StatelessWidget {
  const _LogoutConfirmDialogBody();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CgColors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CgColors.red50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, size: 30, color: CgColors.destructive),
            ),
            const SizedBox(height: 20),
            const Text(
              'Log Out?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CgColors.gray900,
                decoration: TextDecoration.none,
                inherit: false,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Are you sure you want to log out of your ConnectGHIN account?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: CgColors.gray600,
                decoration: TextDecoration.none,
                inherit: false,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await context.read<AuthSession>().logout();
                  if (context.mounted) context.go(AppPaths.welcome);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CgColors.destructive,
                  foregroundColor: CgColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CgColors.white,
                    decoration: TextDecoration.none,
                    inherit: false,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CgColors.gray900,
                  backgroundColor: CgColors.white,
                  side: const BorderSide(color: CgColors.gray300, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CgColors.gray900,
                    decoration: TextDecoration.none,
                    inherit: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
