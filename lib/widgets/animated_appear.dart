import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';

/// Fades, lifts and gently pops a child into view. Pass [index] to stagger a
/// list of these so cards appear one after another.
class AnimatedAppear extends StatefulWidget {
  const AnimatedAppear({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = const Offset(0, 0.10),
    this.scaleFrom = 0.96,
    this.duration = AppMotion.medium,
  });

  final Widget child;
  final int index;
  final Offset offset;
  final double scaleFrom;
  final Duration duration;

  @override
  State<AnimatedAppear> createState() => _AnimatedAppearState();
}

class _AnimatedAppearState extends State<AnimatedAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    final Duration delay = AppMotion.stagger * (widget.index.clamp(0, 12));
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasized,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: widget.offset, end: Offset.zero)
            .animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: widget.scaleFrom, end: 1.0)
              .animate(curved),
          child: widget.child,
        ),
      ),
    );
  }
}
