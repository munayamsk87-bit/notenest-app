import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// A row of pastel colour swatches for notes and labels.
class NoteColorPicker extends StatelessWidget {
  const NoteColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.includeDefault = true,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final bool includeDefault;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<NoteColorOption> options = includeDefault
        ? NoteColors.all
        : NoteColors.all.where((NoteColorOption o) => o.value != 0).toList();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final NoteColorOption option = options[index];
          final bool active = option.value == selected;
          final Color swatch = isDark ? option.dark : option.light;
          return GestureDetector(
            onTap: () => onSelected(option.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black.withOpacity(0.08),
                  width: active ? 2.6 : 1,
                ),
              ),
              child: active
                  ? Icon(Icons.check_rounded,
                      size: 20, color: Theme.of(context).colorScheme.primary)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
