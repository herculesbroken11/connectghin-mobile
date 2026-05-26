import 'package:flutter/material.dart';

import '../../generated/brand_logo_bytes.dart';

/// ConnectGHIN brand logo (embedded bytes; avoids Windows file-lock on asset PNG copy).
class CgAppLogo extends StatelessWidget {
  const CgAppLogo({super.key, this.height = 88});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      kBrandLogoPngBytes,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const Icon(Icons.sports_golf, size: 48, color: Color(0xFF166534)),
    );
  }
}
