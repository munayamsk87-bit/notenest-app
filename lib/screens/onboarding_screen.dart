import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/context_ext.dart';
import '../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';

/// Optional, skippable onboarding (Spec §13). Never blocks access to notes.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_Slide> _slides = <_Slide>[
    _Slide(Icons.edit_note_rounded, 'Write it down',
        'Quick notes, rich text and checklists that save themselves.'),
    _Slide(Icons.photo_camera_back_rounded, 'More than words',
        'Attach pictures, record voice notes and sketch ideas.'),
    _Slide(Icons.alarm_rounded, 'Never forget',
        'Set reminders that reach you even after a restart.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await context.read<SettingsProvider>().setOnboardingDone(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final bool last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(context.t('onboardingSkip')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (int i) => setState(() => _page = i),
                itemBuilder: (BuildContext context, int index) {
                  final _Slide slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: _pastels[index % _pastels.length],
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Icon(slide.icon, size: 66),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.body,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(_slides.length, (int i) {
                final bool active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? context.scheme.primary
                        : context.scheme.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (last) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(
                    last ? context.t('onboardingStart') : context.t('onboardingNext'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<Color> _pastels = <Color>[
    AppColors.lavender,
    AppColors.mintGreen,
    AppColors.skyBlue,
  ];
}

class _Slide {
  const _Slide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}
