import 'dart:io';

import 'package:flutter/material.dart';

import '../core/constants/enums.dart';
import '../core/l10n/context_ext.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/date_utils.dart';
import '../data/models/attachment.dart';
import '../data/models/label.dart';
import '../data/models/note.dart';
import 'pressable.dart';

/// A rounded note card used in both grid and list layouts (Spec §2/§3).
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.done = 0,
    this.total = 0,
    this.attachments = const <Attachment>[],
    this.labels = const <Label>[],
    this.selected = false,
    this.selectionMode = false,
    this.isGrid = true,
    this.showReminder = true,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int done;
  final int total;
  final List<Attachment> attachments;
  final List<Label> labels;
  final bool selected;
  final bool selectionMode;
  final bool isGrid;
  final bool showReminder;

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    final Color cardColor = NoteColors.resolve(note.color, Theme.of(context).brightness);
    final Attachment? image = _firstImage();
    final bool showChecklist = note.type == NoteType.checklist && total > 0;

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (image != null) _imageHeader(image),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (note.title.trim().isNotEmpty)
                Text(
                  note.title.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              if (note.title.trim().isNotEmpty &&
                  (note.preview.isNotEmpty || showChecklist))
                const SizedBox(height: 6),
              if (note.type == NoteType.link && note.linkUrl != null)
                _linkPreview(context)
              else if (showChecklist)
                _checklistPreview(context)
              else if (note.preview.isNotEmpty)
                Text(
                  note.preview,
                  maxLines: isGrid ? 6 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (labels.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _labelChips(context),
              ],
              const SizedBox(height: 10),
              _footer(context),
            ],
          ),
        ),
      ],
    );

    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              cardColor,
              Color.alphaBlend(
                AppColors.champagne.withOpacity(isDark ? 0.06 : 0.10),
                cardColor,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : (note.isPinned
                    ? AppColors.goldHairline
                    : Colors.black.withOpacity(isDark ? 0.22 : 0.05)),
            width: selected ? 2 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.plum.withOpacity(isDark ? 0.45 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: body,
            ),
            if (selectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: _selectionDot(context),
              ),
          ],
        ),
      ),
    );
  }

  Attachment? _firstImage() {
    for (final Attachment a in attachments) {
      if (a.type == AttachmentType.image || a.type == AttachmentType.drawing) {
        return a;
      }
    }
    return null;
  }

  Widget _imageHeader(Attachment image) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Image.file(
        File(image.path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.black.withOpacity(0.06),
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
  }

  Widget _linkPreview(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(Icons.link_rounded, size: 18, color: context.scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            note.body.trim().isEmpty ? note.linkUrl! : note.body.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _checklistPreview(BuildContext context) {
    final double fraction = total == 0 ? 0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: Colors.black.withOpacity(0.08),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.t('completedOf', <String, Object>{'done': done, 'total': total}),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  Widget _labelChips(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels
          .take(3)
          .map((Label l) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l.name,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ))
          .toList(),
    );
  }

  Widget _footer(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(_typeIcon(note.type), size: 14, color: Colors.black.withOpacity(0.45)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            AppDateUtils.relative(note.updatedAt),
            style: Theme.of(context).textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showReminder && note.hasReminder)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.alarm_rounded,
                size: 15, color: context.scheme.primary),
          ),
        if (note.isFavorite)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(Icons.star_rounded, size: 16, color: Color(0xFFE0A800)),
          ),
        if (note.isPinned)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(Icons.push_pin_rounded,
                size: 15, color: Colors.black.withOpacity(0.55)),
          ),
      ],
    );
  }

  Widget _selectionDot(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? context.scheme.primary : Colors.black.withOpacity(0.25),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.6),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }

  IconData _typeIcon(NoteType type) {
    switch (type) {
      case NoteType.text:
        return Icons.notes_rounded;
      case NoteType.checklist:
        return Icons.checklist_rounded;
      case NoteType.image:
        return Icons.image_rounded;
      case NoteType.voice:
        return Icons.mic_rounded;
      case NoteType.drawing:
        return Icons.brush_rounded;
      case NoteType.link:
        return Icons.link_rounded;
    }
  }
}
