import 'package:flutter/material.dart';

/// ConnectGHIN brand logo from [assets/branding/connectghin_logo.png].
class CgAppLogo extends StatelessWidget {
  const CgAppLogo({super.key, this.height = 88});

  static const String assetPath = 'assets/branding/connectghin_logo.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const Icon(Icons.sports_golf, size: 48, color: Color(0xFF166534)),
    );
  }
}
