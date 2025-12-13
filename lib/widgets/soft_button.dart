import 'package:flutter/material.dart';

class SoftButton extends OutlinedButton {
  static ButtonStyle _mergeStyles(
    Color? color,
    ButtonStyle? externalStyle,
    bool? selected,
  ) {
    color ??= ThemeData().colorScheme.primary;
    final base = ButtonStyle(
      side: WidgetStatePropertyAll(BorderSide(color: Colors.transparent)),
      backgroundColor: WidgetStatePropertyAll(
        color.withAlpha(selected == true ? 40 : 13),
      ),
      overlayColor: WidgetStatePropertyAll(color.withAlpha(20)),
    );

    if (externalStyle == null) {
      return base;
    }
    return base.merge(externalStyle);
  }

  SoftButton({
    super.key,
    required super.onPressed,
    required super.child,
    Color? color,
    ButtonStyle? style,
    bool? selected,
  }) : super(style: _mergeStyles(color, style, selected));
}
