import 'package:flutter/material.dart';

/// A small section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.icon,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
          const Spacer(),
          if (trailing != null)
            TextButton(
              onPressed: onTrailingTap,
              child: Text(trailing!),
            ),
        ],
      ),
    );
  }
}
