import 'package:flutter/material.dart';

/// Keeps content readable on tablets/foldables by limiting max width.
class CgResponsiveContainer extends StatelessWidget {
  const CgResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 560,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
