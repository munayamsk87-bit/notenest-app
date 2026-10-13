import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import 'animated_appear.dart';
import 'floating_blobs.dart';

/// Friendly, illustrated empty state with a gently floating icon (Spec §2/§3).
class EmptyState extends StatefulWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add_rounded,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return FloatingBlobs(
      seed: widget.icon.codePoint % 5,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: AnimatedAppear(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedBuilder(
                  animation: _float,
                  builder: (BuildContext context, Widget? child) {
                    final double lift = Curves.easeInOut.transform(_float.value);
                    return Transform.translate(
                      offset: Offset(0, -6 * lift),
                      child: Transform.rotate(
                        angle: (-0.03 + 0.06 * lift),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 122,
                    height: 122,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? <Color>[AppColors.darkSurfaceAlt, AppColors.darkSurface]
                            : <Color>[AppColors.lavender, AppColors.softPink],
                      ),
                      borderRadius: BorderRadius.circular(38),
                      boxShadow: <BoxShadow>[
                        if (!isDark)
                          BoxShadow(
                            color: scheme.primary.withOpacity(0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 12),
                          ),
                      ],
                    ),
                    child: Icon(widget.icon, size: 56, color: scheme.primary),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (widget.actionLabel != null && widget.onAction != null) ...<Widget>[
                  const SizedBox(height: 24),
                  AnimatedAppear(
                    index: 2,
                    child: _PressableButton(
                      onTap: widget.onAction!,
                      icon: widget.actionIcon,
                      label: widget.actionLabel!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A button that springs a little when pressed.
class _PressableButton extends StatefulWidget {
  const _PressableButton({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String label;

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _down ? 0.95 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.springy,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: FilledButton.icon(
          onPressed: widget.onTap,
          icon: Icon(widget.icon),
          label: Text(widget.label),
        ),
      ),
    );
  }
}
