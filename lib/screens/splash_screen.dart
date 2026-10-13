import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../data/services/app_lock_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/floating_blobs.dart';

/// Splash + routing gate with an animated brand mark. Honours the app lock,
/// then sends first-time users to optional onboarding.
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
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _intro.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  @override
  void dispose() {
    _intro.dispose();
    _float.dispose();
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

  Future<int> _waitForReady(SettingsProvider settings) async {
    int elapsed = 0;
    while (!settings.ready && elapsed < 3000) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      elapsed += 100;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return elapsed;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: FloatingBlobs(
        opacity: 0.7,
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_intro, _float]),
            builder: (BuildContext context, Widget? _) {
              final double intro = Curves.easeOutBack.transform(
                _intro.value.clamp(0.0, 1.0),
              );
              final double lift = Curves.easeInOut.transform(_float.value);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Opacity(
                    opacity: _intro.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -8 * lift + (1 - intro) * 20),
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * intro,
                        child: Transform.rotate(
                          angle: (-0.05 + 0.10 * lift) * (1 - intro * 0.5),
                          child: _brandMark(isDark),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Opacity(
                    opacity: _intro.value.clamp(0.0, 1.0),
                    child: Text(
                      'NoteNest',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Opacity(
                    opacity: (_intro.value * 1.2).clamp(0.0, 1.0),
                    child: Text(
                      _locked
                          ? 'Unlock to see your notes'
                          : 'Your little space for big ideas',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 30),
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
                    const _BouncingDots(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _brandMark(bool isDark) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[AppColors.darkSurfaceAlt, AppColors.darkSurface]
              : <Color>[AppColors.lavender, AppColors.softPink],
        ),
        borderRadius: BorderRadius.circular(36),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.primaryPurple)
                .withOpacity(0.25),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Icon(Icons.auto_stories_rounded,
              size: 58,
              color: isDark ? AppColors.darkTextMain : AppColors.primaryPurple),
          Positioned(
            top: 18,
            right: 20,
            child: Transform.rotate(
              angle: 0.2,
              child: Icon(Icons.star_rounded,
                  size: 26, color: Colors.amber.withOpacity(0.95)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three dots that bob in sequence — a soft stand-in for a spinner.
class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (int i) {
            final double phase = (_controller.value + i / 3) % 1.0;
            final double bump = (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, -6 * bump),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.35 + 0.65 * bump),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Kept for callers that want the shared motion constants.
const Duration kSplashBeat = AppMotion.slow;
