import 'dart:async';

import 'package:flutter/material.dart';

/// The NoteNest mascot — a chibi notebook that blinks and gently bobs.
class Mascot extends StatefulWidget {
  const Mascot({
    super.key,
    this.size = 160,
    this.bob = true,
    this.blink = true,
  });

  final double size;
  final bool bob;
  final bool blink;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  static const String _open = 'assets/mascot/mascot.png';
  static const String _closed = 'assets/mascot/mascot_blink.png';

  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  Timer? _blinkTimer;
  Timer? _openTimer;
  bool _blinking = false;

  @override
  void initState() {
    super.initState();
    if (widget.blink) _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      setState(() => _blinking = true);
      _openTimer = Timer(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() => _blinking = false);
        _scheduleBlink();
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _openTimer?.cancel();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      _blinking ? _closed : _open,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    if (!widget.bob) return image;

    return AnimatedBuilder(
      animation: _bob,
      builder: (BuildContext context, Widget? child) {
        final double lift = Curves.easeInOut.transform(_bob.value);
        return Transform.translate(
          offset: Offset(0, -7 * lift),
          child: Transform.rotate(angle: (-0.02 + 0.04 * lift), child: child),
        );
      },
      child: image,
    );
  }
}

/// A small circular mascot avatar, handy in headers.
class MascotAvatar extends StatelessWidget {
  const MascotAvatar({super.key, this.size = 38});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Theme.of(context).colorScheme.primary.withOpacity(0.18),
            Theme.of(context).colorScheme.primary.withOpacity(0.06),
          ],
        ),
      ),
      padding: EdgeInsets.all(size * 0.10),
      child: Image.asset(
        'assets/mascot/mascot.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
