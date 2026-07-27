import 'package:flutter/material.dart';

/// Vertical gap that shrinks on short screens (e.g. LDPlayer).
double cgCompactGap(BuildContext context, double base) {
  final h = MediaQuery.sizeOf(context).height;
  if (h >= 760) return base;
  if (h >= 660) return base * 0.72;
  return base * 0.55;
}

/// Auth logo height by viewport — larger for Connectghin brand presence.
double cgAuthLogoHeight(BuildContext context) {
  final h = MediaQuery.sizeOf(context).height;
  if (h < 640) return 112;
  if (h < 760) return 136;
  return 160;
}

bool cgIsShortScreen(BuildContext context) => MediaQuery.sizeOf(context).height < 760;

/// Fits [child] on screen without scrolling; scrolls only when the keyboard is open.
class CgFitHeightBody extends StatelessWidget {
  const CgFitHeightBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.allowScrollWhenKeyboard = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool allowScrollWhenKeyboard;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - padding.horizontal;
        final content = Padding(
          padding: padding,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: width, child: child),
          ),
        );

        if (allowScrollWhenKeyboard && keyboard) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        }

        return SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth,
              child: content,
            ),
          ),
        );
      },
    );
  }
}
