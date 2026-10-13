import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_motion.dart';
import '../data/services/app_lock_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/floating_blobs.dart';
import '../widgets/gradient_backdrop.dart';
import '../widgets/mascot.dart';
import '../widgets/shimmer_sweep.dart';

/// The opening experience: an animated pastel gradient, rising sparkles and the
/// NoteNest mascot popping in — then it routes to the home screen (honouring
/// the app lock first).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _locked = false;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final AnimationController _sparkles = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _intro.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  @override
  void dispose() {
    _intro.dispose();
    _sparkles.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    final SettingsProvider settings = context.read<SettingsProvider>();
    await _waitForReady(settings);
    if (!mounted) return;

    if (settings.appLockEnabled) {
      final bool ok = await AppLockService.instance
          .authenticate(reason: 'Authenticate to open your notes');
      if (!mounted) return;
      if (!ok) {
        setState(() => _locked = true);
        return;
      }
    }

    Navigator.of(context).pushReplacementNamed(
      settings.onboardingDone ? '/home' : '/onboarding',
    );
  }

  Future<void> _waitForReady(SettingsProvider settings) async {
    int elapsed = 0;
    while (!settings.ready && elapsed < 3000) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      elapsed += 100;
    }
    // A beat so the opening animation reads properly.
    await Future<void>.delayed(const Duration(milliseconds: 1250));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackdrop(
        child: FloatingBlobs(
          opacity: 0.5,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _sparkles,
                    builder: (BuildContext context, Widget? _) => CustomPaint(
                      painter: _RisingSparkles(t: _sparkles.value),
                    ),
                  ),
                ),
              ),
              Center(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (BuildContext context, Widget? _) {
                    final double v = Curves.easeOutCubic
                        .transform(_intro.value.clamp(0.0, 1.0));
                    final double pop = Curves.easeOutBack
                        .transform(_intro.value.clamp(0.0, 1.0));
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Opacity(
                          opacity: v,
                          child: Transform.scale(
                            scale: 0.55 + 0.45 * pop,
                            child: const Mascot(size: 190),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, (1 - v) * 16),
                            child: Column(
                              children: <Widget>[
                                ShimmerSweep(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Text(
                                    'NoteNest',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const GoldRule(width: 72),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: (v * 1.25).clamp(0.0, 1.0),
                          child: Text(
                            _locked
                                ? 'Unlock to see your notes'
                                : 'Your little space for big ideas',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(height: 34),
                        if (_locked)
                          FilledButton.icon(
                            onPressed: () {
                              setState(() => _locked = false);
                              _route();
                            },
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: const Text('Unlock NoteNest'),
                          )
                        else
                          _LoadingBar(visible: _intro.isCompleted),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A slim rounded progress bar that fills while the app warms up.
class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: AppMotion.medium,
      child: SizedBox(
        width: 150,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOutCubic,
          builder: (BuildContext context, double v, Widget? _) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.45),
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Little pastel stars drifting upward behind the mascot.
class _RisingSparkles extends CustomPainter {
  _RisingSparkles({required this.t});

  final double t;

  static const List<Color> _colors = <Color>[
    Color(0xFFFFD75E),
    Color(0xFFFFFFFF),
    Color(0xFFB79BEF),
    Color(0xFFFFB3CE),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const int count = 14;
    for (int i = 0; i < count; i++) {
      final double seed = i * 0.137;
      final double phase = (t + seed) % 1.0;
      final double x = size.width * ((i * 0.191 + 0.05) % 1.0);
      final double y = size.height * (1.08 - phase * 1.16);
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final double r = 5 + 5 * ((i % 3) / 2);
      final Paint paint = Paint()
        ..color = _colors[i % _colors.length].withOpacity(0.75 * fade);
      _star(canvas, Offset(x, y), r, paint);
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final Path path = Path();
    for (int i = 0; i < 8; i++) {
      final double rad = i.isEven ? r : r * 0.38;
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
  bool shouldRepaint(_RisingSparkles old) => old.t != t;
}

/// Kept so the shared motion constants stay referenced.
const Duration kSplashBeat = AppMotion.slow;
