import 'package:flutter/material.dart';

import '../core/l10n/context_ext.dart';
import '../core/theme/app_colors.dart';

/// Every AI action the user can run on a note.
enum AiActionKind {
  summarize,
  keyPoints,
  continueWriting,
  suggestTitle,
  fixGrammar,
  shorten,
  expand,
  tone,
  translate,
  checklist,
  labels,
  ask,
}

/// A chosen action, plus any parameter (tone or target language).
class AiActionChoice {
  const AiActionChoice(this.kind, {this.param});
  final AiActionKind kind;
  final String? param;
}

/// The AI tools sheet: grouped, discoverable actions for the open note.
Future<AiActionChoice?> showAiActionsSheet(BuildContext context) {
  return showModalBottomSheet<AiActionChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _header(ctx),
              _sectionLabel(ctx, ctx.t('aiWrite')),
              _tile(ctx, Icons.summarize_rounded, ctx.t('summarize'),
                  const AiActionChoice(AiActionKind.summarize)),
              _tile(ctx, Icons.format_list_bulleted_rounded, ctx.t('keyPoints'),
                  const AiActionChoice(AiActionKind.keyPoints)),
              _tile(ctx, Icons.title_rounded, ctx.t('suggestTitle'),
                  const AiActionChoice(AiActionKind.suggestTitle)),
              _tile(ctx, Icons.edit_note_rounded, ctx.t('continueWriting'),
                  const AiActionChoice(AiActionKind.continueWriting)),
              _sectionLabel(ctx, ctx.t('aiPolish')),
              _tile(ctx, Icons.spellcheck_rounded, ctx.t('fixGrammar'),
                  const AiActionChoice(AiActionKind.fixGrammar)),
              _tile(ctx, Icons.compress_rounded, ctx.t('shorten'),
                  const AiActionChoice(AiActionKind.shorten)),
              _tile(ctx, Icons.expand_rounded, ctx.t('expand'),
                  const AiActionChoice(AiActionKind.expand)),
              _tile(ctx, Icons.record_voice_over_rounded, ctx.t('tone'), null,
                  onTap: () async {
                final String? tone = await _pickOption(ctx, ctx.t('tone'), <String>[
                  ctx.t('toneProfessional'),
                  ctx.t('toneFriendly'),
                  ctx.t('toneCasual'),
                  ctx.t('toneConfident'),
                ]);
                if (tone != null && ctx.mounted) {
                  Navigator.of(ctx)
                      .pop(AiActionChoice(AiActionKind.tone, param: tone));
                }
              }),
              _tile(ctx, Icons.translate_rounded, ctx.t('translate'), null,
                  onTap: () async {
                final String? lang =
                    await _pickOption(ctx, ctx.t('translate'), <String>[
                  ctx.t('languageEnglish'),
                  ctx.t('languageBengali'),
                  ctx.t('languageHindi'),
                ]);
                if (lang != null && ctx.mounted) {
                  Navigator.of(ctx)
                      .pop(AiActionChoice(AiActionKind.translate, param: lang));
                }
              }),
              _sectionLabel(ctx, ctx.t('aiOrganise')),
              _tile(ctx, Icons.checklist_rounded, ctx.t('generateChecklist'),
                  const AiActionChoice(AiActionKind.checklist)),
              _tile(ctx, Icons.label_outline_rounded, ctx.t('suggestLabels'),
                  const AiActionChoice(AiActionKind.labels)),
              _sectionLabel(ctx, ctx.t('aiAsk')),
              _tile(ctx, Icons.forum_rounded, ctx.t('aiAskTitle'),
                  const AiActionChoice(AiActionKind.ask)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.lock_outline_rounded,
                        size: 14, color: Theme.of(ctx).hintColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ctx.t('aiConsent'),
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
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

Widget _header(BuildContext ctx) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
    child: Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: <Color>[
                ctx.scheme.primary,
                AppColors.gold,
              ],
            ),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(
          ctx.t('aiTools'),
          style: Theme.of(ctx)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

Widget _sectionLabel(BuildContext ctx, String text) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: AppColors.gold,
          ),
    ),
  );
}

Widget _tile(
  BuildContext ctx,
  IconData icon,
  String label,
  AiActionChoice? choice, {
  Future<void> Function()? onTap,
}) {
  return ListTile(
    leading: Icon(icon, color: ctx.scheme.primary),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
    onTap: onTap != null
        ? () {
            onTap();
          }
        : () => Navigator.of(ctx).pop(choice),
  );
}

Future<String?> _pickOption(
    BuildContext context, String title, List<String> options) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          for (final String option in options)
            ListTile(
              title: Text(option),
              onTap: () => Navigator.of(ctx).pop(option),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
