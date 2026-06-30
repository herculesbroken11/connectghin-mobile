import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/design_tokens.dart';

/// Shown when the user presses the system back button on a main tab root screen.
class ExitAppConfirmDialog {
  ExitAppConfirmDialog._();

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: CgColors.gray900.withValues(alpha: 0.32),
      builder: (dialogContext) => const _ExitAppConfirmDialogBody(),
    );
    return result ?? false;
  }
}

class _ExitAppConfirmDialogBody extends StatelessWidget {
  const _ExitAppConfirmDialogBody();

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
              decoration: const BoxDecoration(
                color: CgColors.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.exit_to_app_rounded, size: 30, color: CgColors.gray700),
            ),
            const SizedBox(height: 20),
            const Text(
              'Exit ConnectGHIN?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CgColors.gray900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Are you sure you want to close the app?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: CgColors.gray600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CgColors.green700,
                  foregroundColor: CgColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Exit',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CgColors.gray900,
                  backgroundColor: CgColors.white,
                  side: const BorderSide(color: CgColors.gray300, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
