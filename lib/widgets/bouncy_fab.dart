import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_motion.dart';

/// A floating action button that springs and twirls its icon while it opens the
/// create sheet.
class BouncyFab extends StatefulWidget {
  const BouncyFab({
    super.key,
    required this.onTap,
    required this.label,
    this.icon = Icons.add_rounded,
  });

  final Future<void> Function() onTap;
  final String label;
  final IconData icon;

  @override
  State<BouncyFab> createState() => _BouncyFabState();
}

class _BouncyFabState extends State<BouncyFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
  );

  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handle() async {
    if (_busy) return;
    _busy = true;
    HapticFeedback.mediumImpact();
    await _controller.forward();
    await widget.onTap();
    if (mounted) {
      await _controller.reverse();
    }
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Transform.scale(
          scale: 1 + 0.05 * _controller.value,
          child: child,
        );
      },
      child: FloatingActionButton.extended(
        onPressed: _handle,
        icon: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) => Transform.rotate(
            angle: _controller.value * math.pi / 4,
            child: Icon(widget.icon),
          ),
        ),
        label: Text(widget.label),
      ),
    );
  }
}
