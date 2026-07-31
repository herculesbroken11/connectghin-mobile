import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/design_tokens.dart';
import '../../../core/widgets/cg_app_logo.dart';

/// Dark green branded header used on Sign In / Create Account.
class CgAuthGreenHero extends StatelessWidget {
  const CgAuthGreenHero({
    super.key,
    required this.onBack,
    this.compact = false,
  });

  final VoidCallback onBack;
  final bool compact;

  static const _bgAsset = 'assets/images/pair_up_header.jpg';

  @override
  Widget build(BuildContext context) {
    final logoH = compact ? 72.0 : 88.0;
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F3A28),
                  CgColors.green900,
                  CgColors.fairway,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.38,
            child: Image.asset(
              _bgAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(0.45, 0.15),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.transparent,
                  const Color(0xFF0F3A28).withValues(alpha: 0.72),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: -20,
          right: -30,
          child: IgnorePointer(
            child: CustomPaint(
              size: const Size(160, 160),
              painter: _DotBurstPainter(),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, compact ? 0 : 4, 16, compact ? 28 : 36),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: CgColors.white),
                  ),
                ),
                CgAuthBrandMark(
                  size: logoH,
                  variant: CgAppLogoVariant.full,
                  plate: true,
                ),
                SizedBox(height: compact ? 10 : 14),
                Text(
                  'Connectghin',
                  style: GoogleFonts.fraunces(
                    color: CgColors.white,
                    fontSize: compact ? 28 : 32,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: compact ? 8 : 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 1,
                      color: CgColors.premiumGoldLight.withValues(alpha: 0.7),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: CgColors.premiumGoldLight,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 1,
                      color: CgColors.premiumGoldLight.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Find your foursome',
                  style: TextStyle(
                    color: CgColors.premiumGoldLight.withValues(alpha: 0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DotBurstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final c = Offset(size.width * 0.55, size.height * 0.45);
    for (var ring = 1; ring <= 5; ring++) {
      final r = ring * 16.0;
      final count = 10 + ring * 4;
      for (var i = 0; i < count; i++) {
        final a = (i / count) * math.pi * 2;
        final x = c.dx + r * math.cos(a);
        final y = c.dy + r * math.sin(a);
        canvas.drawCircle(Offset(x, y), ring == 5 ? 1.4 : 1.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Brand logo on auth screens (full art on a light plate for dark headers).
class CgAuthBrandMark extends StatelessWidget {
  const CgAuthBrandMark({
    super.key,
    this.size = 88,
    this.variant = CgAppLogoVariant.full,
    this.plate = true,
  });

  /// Max height of the logo image.
  final double size;
  final CgAppLogoVariant variant;
  final bool plate;

  @override
  Widget build(BuildContext context) {
    return CgAppLogo(height: size, variant: variant, plate: plate);
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
    return Material(
      color: CgColors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: busy ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: minHeight,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CgColors.gray200),
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
                style: TextStyle(
                  fontSize: minHeight < 46 ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  color: CgColors.gray900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visible auth error (login/register screens — not hidden snackbars).
class CgAuthInlineError extends StatelessWidget {
  const CgAuthInlineError({super.key, required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CgColors.red50,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: CgColors.red700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: CgColors.red700, fontSize: 13, height: 1.35),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18, color: CgColors.red700),
              ),
          ],
        ),
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
        const Icon(Icons.verified_user_outlined, size: 16, color: CgColors.green700),
        const SizedBox(width: 5),
        Text(secureLabel, style: const TextStyle(fontSize: 12, color: CgColors.gray600, fontWeight: FontWeight.w500)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          width: 1,
          height: 14,
          color: CgColors.gray300,
        ),
        const Icon(Icons.lock_outline, size: 16, color: CgColors.green700),
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
