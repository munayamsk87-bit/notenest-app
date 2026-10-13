import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// A soft champagne-gold light sweep that glides across its child — the little
/// luxury flourish used on the logo and premium cards.
class ShimmerSweep extends StatefulWidget {
  const ShimmerSweep({
    super.key,
    required this.child,
    this.enabled = true,
    this.period = const Duration(milliseconds: 2600),
    this.color = AppColors.champagne,
    this.borderRadius = BorderRadius.zero,
  });

  final Widget child;
  final bool enabled;
  final Duration period;
  final Color color;
  final BorderRadius borderRadius;

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(ShimmerSweep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = _controller.value;
          return Stack(
            children: <Widget>[
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.6 + 3.2 * t, -0.4),
                        end: Alignment(-0.9 + 3.2 * t, 0.4),
                        colors: <Color>[
                          widget.color.withOpacity(0.0),
                          widget.color.withOpacity(0.38),
                          Colors.white.withOpacity(0.30),
                          widget.color.withOpacity(0.0),
                        ],
                        stops: const <double>[0.0, 0.42, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A hairline divider with a soft gold gradient in the middle.
class GoldRule extends StatelessWidget {
  const GoldRule({super.key, this.width = 64, this.thickness = 2});

  final double width;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: thickness,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(thickness),
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.champagne.withOpacity(0.0),
            AppColors.gold,
            AppColors.champagne.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}
