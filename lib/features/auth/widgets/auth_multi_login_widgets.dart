import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../core/widgets/cg_app_logo.dart';

/// Brand logo on auth screens.
class CgAuthBrandMark extends StatelessWidget {
  const CgAuthBrandMark({super.key, this.size = 88});

  /// Max height of the logo image.
  final double size;

  @override
  Widget build(BuildContext context) {
    return CgAppLogo(height: size);
  }
}

/// Full-width outlined social button (Apple / Google).
class CgSocialSignInButton extends StatelessWidget {
  const CgSocialSignInButton({
    super.key,
    required this.label,
    required this.leading,
    required this.onPressed,
    this.busy = false,
    this.minHeight = 48,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  final bool busy;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: CgColors.gray900,
        backgroundColor: CgColors.white,
        side: const BorderSide(color: CgColors.gray300),
        minimumSize: Size(double.infinity, minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: CgColors.green700),
            )
          else
            leading,
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: minHeight < 46 ? 14 : 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class CgOrDivider extends StatelessWidget {
  const CgOrDivider({super.key, this.label = 'or'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: CgColors.gray300, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: const TextStyle(color: CgColors.gray500, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        const Expanded(child: Divider(color: CgColors.gray300, thickness: 1)),
      ],
    );
  }
}

/// Small trust row for login / register footers.
class CgAuthTrustFooter extends StatelessWidget {
  const CgAuthTrustFooter({
    super.key,
    this.secureLabel = 'Secure',
    this.privateLabel = 'Private',
  });

  final String secureLabel;
  final String privateLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_outlined, size: 17, color: CgColors.green700),
        const SizedBox(width: 5),
        Text(secureLabel, style: const TextStyle(fontSize: 12, color: CgColors.gray600, fontWeight: FontWeight.w500)),
        const SizedBox(width: 22),
        const Icon(Icons.lock_outline, size: 17, color: CgColors.green700),
        const SizedBox(width: 5),
        Text(privateLabel, style: const TextStyle(fontSize: 12, color: CgColors.gray600, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// Builds a valid [username] (min 3 chars) for `/auth/register` from display name + email fallback.
String derivedUsernameFromFullName(String fullName, String email) {
  var s = fullName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  s = s.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  if (s.length < 3) {
    final local = email.trim().split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    s = local.isNotEmpty ? local : 'golfer';
  }
  if (s.length < 3) {
    s = '${s}_user';
  }
  if (s.length > 30) {
    s = s.substring(0, 30);
  }
  return s;
}
