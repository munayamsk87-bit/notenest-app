import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Plays a short, cheerful sparkle burst over the current screen — used when a
/// checklist is completed. Removes itself when done.
Future<void> showSparkleBurst(
  BuildContext context, {
  Offset? origin,
  int count = 16,
}) {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  final Completer<void> done = Completer<void>();
  final Size size = MediaQuery.of(context).size;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext ctx) => _SparkleLayer(
      origin: origin ?? Offset(size.width / 2, size.height * 0.42),
      count: count,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (!done.isCompleted) done.complete();
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _SparkleLayer extends StatefulWidget {
  const _SparkleLayer({
    required this.origin,
    required this.count,
    required this.onDone,
  });

  final Offset origin;
  final int count;
  final VoidCallback onDone;

  @override
  State<_SparkleLayer> createState() => _SparkleLayerState();
}

class _SparkleLayerState extends State<_SparkleLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) => CustomPaint(
          painter: _SparklePainter(
            progress: _controller.value,
            origin: widget.origin,
            count: widget.count,
          ),
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({
    required this.progress,
    required this.origin,
    required this.count,
  });

  final double progress;
  final Offset origin;
  final int count;

  static const List<Color> _colors = <Color>[
    Color(0xFFFFD75E),
    Color(0xFF8060C7),
    Color(0xFFE0709A),
    Color(0xFF4FB286),
    Color(0xFF5B9BD5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double eased = Curves.easeOutCubic.transform(progress);
    final double fade = (1 - progress).clamp(0.0, 1.0);
    for (int i = 0; i < count; i++) {
      final double angle = (i / count) * 2 * math.pi;
      final double distance = 30 + 120 * eased * (0.6 + 0.4 * ((i % 3) / 2));
      final Offset center = origin +
          Offset(math.cos(angle), math.sin(angle) - 0.4) * distance;
      final double r = (3 + 4 * (1 - eased)) * fade;
      if (r <= 0.2) continue;
      final Paint paint = Paint()
        ..color = _colors[i % _colors.length].withOpacity(fade);
      _drawStar(canvas, center, r, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final Path path = Path();
    for (int i = 0; i < 8; i++) {
      final double rad = (i.isEven ? r : r * 0.4);
      final double a = (i / 8) * 2 * math.pi - math.pi / 2;
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * rad;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.progress != progress;
}

/// A soft shimmering placeholder used while content loads.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 12,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color base = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.05);
    final Color highlight = isDark
        ? Colors.white.withOpacity(0.13)
        : Colors.white.withOpacity(0.65);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * t + 3 * t, 0),
              end: Alignment(1 - 2 * t + 3 * t, 0),
              colors: <Color>[base, highlight, base],
              stops: const <double>[0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
