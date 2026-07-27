import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';

/// Amber CTA shown when a premium-only action is locked.
class CgPremiumLockedCta extends StatelessWidget {
  const CgPremiumLockedCta({
    super.key,
    required this.message,
    this.helpText,
    this.onUpgrade,
  });

  final String message;
  final String? helpText;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: CgColors.yellow50,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onUpgrade ?? () => context.push(AppPaths.appMembership),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CgColors.premiumGold, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: CgColors.premiumGoldDark, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CgColors.premiumGoldDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (helpText != null) ...[
          const SizedBox(height: 6),
          Text(
            helpText!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: CgColors.gray500),
          ),
        ],
      ],
    );
  }
}

/// Centered premium upgrade modal overlay content.
class CgPremiumGateModal extends StatelessWidget {
  const CgPremiumGateModal({
    super.key,
    this.title = 'Premium members only',
    this.subtitle = 'Unlock Find Your 4th features',
    this.onUpgrade,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          color: CgColors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 12,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: CgColors.yellow100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, color: CgColors.premiumGoldDark, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CgColors.gray900),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: CgColors.gray600),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onUpgrade ??
                        () {
                          Navigator.of(context).pop();
                          context.push(AppPaths.appMembership);
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CgColors.premiumGold,
                      foregroundColor: CgColors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Upgrade to Premium',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
