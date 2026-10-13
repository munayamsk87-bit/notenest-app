import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// A slow, breathing pastel gradient used behind the splash and empty states.
class GradientBackdrop extends StatefulWidget {
  const GradientBackdrop({super.key, required this.child, this.colors});

  final Widget child;
  final List<Color>? colors;

  @override
  State<GradientBackdrop> createState() => _GradientBackdropState();
}

class _GradientBackdropState extends State<GradientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> colors = widget.colors ??
        (isDark
            ? <Color>[AppColors.darkBackground, AppColors.darkSurface, AppColors.darkSurfaceAlt]
            : <Color>[AppColors.lavender, AppColors.softPink, AppColors.skyBlue]);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(_controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 0.6 * t, -1),
              end: Alignment(1, 1 - 0.6 * t),
              colors: colors,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
