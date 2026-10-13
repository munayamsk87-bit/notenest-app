import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../data/services/app_lock_service.dart';
import '../providers/settings_provider.dart';

/// Splash + routing gate. Honours the app lock, then sends first-time users to
/// optional onboarding (which can be skipped — it never blocks local notes).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    // Let providers finish loading their persisted state.
    final SettingsProvider settings = context.read<SettingsProvider>();
    await _waitForReady(settings);
    if (!mounted) return;

    // Enforce the optional app lock before showing any notes (Spec §12).
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
    // A short, tasteful beat so the brand mark is visible.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return elapsed;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (_locked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceAlt : AppColors.lavender,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.lock_rounded, size: 44),
              ),
              const SizedBox(height: 20),
              Text(
                'Unlock NoteNest',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _locked = false);
                  _route();
                },
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceAlt : AppColors.lavender,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.auto_stories_rounded, size: 52),
            ),
            const SizedBox(height: 20),
            Text(
              'NoteNest',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Your little space for big ideas',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
