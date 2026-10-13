import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'mascot.dart';
import 'pressable.dart';
import 'shimmer_sweep.dart';

/// One small metric shown inside the premium banner.
class PremiumStat {
  const PremiumStat(this.icon, this.value, this.label);
  final IconData icon;
  final String value;
  final String label;
}

/// A refined gradient hero card with a champagne hairline, a gliding gold
/// shimmer and the mascot — the luxury centrepiece of the home screen.
class PremiumBanner extends StatelessWidget {
  const PremiumBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stats,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final List<PremiumStat> stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: PressableScale(
        onTap: onTap,
        scale: 0.985,
        child: ShimmerSweep(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? <Color>[
                        scheme.primary.withOpacity(0.30),
                        AppColors.darkSurfaceAlt,
                      ]
                    : <Color>[
                        scheme.primary.withOpacity(0.16),
                        AppColors.champagne.withOpacity(0.28),
                        AppColors.softPink.withOpacity(0.22),
                      ],
              ),
              border: Border.all(color: AppColors.goldHairline, width: 1),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.plum.withOpacity(isDark ? 0.45 : 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const GoldRule(width: 26),
                          const SizedBox(width: 8),
                          Text(
                            'PREMIUM',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  letterSpacing: 2.2,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: stats
                            .map((PremiumStat s) => _StatPill(stat: s))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Mascot(size: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.stat});

  final PremiumStat stat;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.white).withOpacity(isDark ? 0.10 : 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldHairline.withOpacity(0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(stat.icon, size: 15, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            stat.value,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 4),
          Text(
            stat.label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
