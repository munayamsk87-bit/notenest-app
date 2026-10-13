import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Slowly drifting pastel blobs painted behind a screen. Purely decorative —
/// it never intercepts touches and stops animating when off-screen.
class FloatingBlobs extends StatefulWidget {
  const FloatingBlobs({
    super.key,
    this.child,
    this.opacity = 0.55,
    this.seed = 0,
  });

  final Widget? child;
  final double opacity;
  final int seed;

  @override
  State<FloatingBlobs> createState() => _FloatingBlobsState();
}

class _FloatingBlobsState extends State<FloatingBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? _) {
                return CustomPaint(
                  painter: _BlobPainter(
                    t: _controller.value,
                    isDark: isDark,
                    opacity: widget.opacity,
                    seed: widget.seed,
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({
    required this.t,
    required this.isDark,
    required this.opacity,
    required this.seed,
  });

  final double t;
  final bool isDark;
  final double opacity;
  final int seed;

  static const List<Color> _pastels = <Color>[
    Color(0xFFE9DDFB), // lavender
    Color(0xFFDDF5E7), // mint
    Color(0xFFDCEEFF), // sky
    Color(0xFFFFE2EA), // pink
    Color(0xFFFFF0BD), // butter
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double phase = (seed * 0.37) + t * 2 * math.pi;
    for (int i = 0; i < 4; i++) {
      final double a = phase + i * 1.9;
      final double dx = size.width * (0.5 + 0.42 * math.sin(a));
      final double dy = size.height * (0.5 + 0.40 * math.cos(a * 1.15));
      final double r = size.shortestSide * (0.30 + 0.06 * math.sin(a * 0.8));
      final Color color = _pastels[(i + seed) % _pastels.length];
      final Paint paint = Paint()
        ..color = color.withOpacity(isDark ? opacity * 0.22 : opacity * 0.75)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 46);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.t != t || old.isDark != isDark || old.opacity != opacity;
}
