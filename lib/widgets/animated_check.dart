import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';

/// A round checkbox that pops and ticks with a spring — used in checklists.
class AnimatedCheckbox extends StatelessWidget {
  const AnimatedCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 26,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.springy,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? scheme.primary : Colors.transparent,
            border: Border.all(
              color: value ? scheme.primary : scheme.outline.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: AnimatedScale(
            scale: value ? 1 : 0,
            duration: AppMotion.fast,
            curve: AppMotion.springy,
            child: Icon(Icons.check_rounded, size: size * 0.66, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
