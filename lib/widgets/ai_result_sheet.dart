import 'package:flutter/material.dart';

import '../core/l10n/context_ext.dart';
import 'shimmer_sweep.dart';

/// What the user chose to do with an AI result.
enum AiResultAction { replace, append, copy, checklist, newNote }

/// Shows the AI result and lets the user apply it in a few useful ways.
Future<AiResultAction?> showAiResultSheet(
  BuildContext context, {
  required String title,
  required String result,
}) {
  return showModalBottomSheet<AiResultAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.auto_awesome_rounded,
                        size: 20, color: ctx.scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const GoldRule(width: 34),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SelectableText(
                    result,
                    style: Theme.of(ctx).textTheme.bodyLarge,
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(ctx).pop(AiResultAction.replace),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: Text(ctx.t('replace')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(ctx).pop(AiResultAction.append),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(ctx.t('appendText')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(ctx).pop(AiResultAction.checklist),
                      icon: const Icon(Icons.checklist_rounded, size: 18),
                      label: Text(ctx.t('aiInsertChecklist')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(ctx).pop(AiResultAction.newNote),
                      icon: const Icon(Icons.note_add_outlined, size: 18),
                      label: Text(ctx.t('aiNewNote')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(ctx).pop(AiResultAction.copy),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(ctx.t('copyText')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
