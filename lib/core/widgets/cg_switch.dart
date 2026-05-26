import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// Compact green toggle used on Settings and privacy screens.
class CgSwitch extends StatelessWidget {
  const CgSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.78,
      alignment: Alignment.centerRight,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        activeThumbColor: CgColors.white,
        activeTrackColor: CgColors.green700,
        inactiveThumbColor: CgColors.white,
        inactiveTrackColor: CgColors.gray300,
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
