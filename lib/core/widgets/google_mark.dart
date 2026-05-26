import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official-style multicolor Google “G” (see assets/branding/google_logo.svg).
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});

  final double size;

  static const _assetPath = 'assets/branding/google_logo.svg';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _assetPath,
      width: size,
      height: size,
      semanticsLabel: 'Google',
    );
  }
}
