import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../generated/brand_logo_bytes.dart';

/// ConnectGHIN brand logo (embedded bytes; avoids Windows file-lock on assets/*.png).
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
      errorBuilder: (_, __, ___) => Icon(Icons.sports_golf, size: height * 0.55, color: CgColors.green800),
    );
  }
}
