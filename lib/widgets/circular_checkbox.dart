import 'package:flutter/material.dart';
import '../app_theme.dart';

/// TeuxDeux風の円形チェックボックス
class CircularCheckbox extends StatelessWidget {
  const CircularCheckbox({
    required this.value,
    required this.onChanged,
    this.size = 24.0,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final checkColor = isDark ? AppTheme.darkBackground : Colors.white;
    final borderColor = isDark ? AppTheme.darkDivider : AppTheme.lightDivider;
    final fillColor = isDark ? AppTheme.accentPurple : AppTheme.primaryPurple;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value ? fillColor : Colors.transparent,
          border: Border.all(
            color: value ? fillColor : borderColor,
            width: 2.0,
          ),
        ),
        child: value
            ? Icon(
                Icons.check,
                size: size * 0.65,
                color: checkColor,
              )
            : null,
      ),
    );
  }
}

