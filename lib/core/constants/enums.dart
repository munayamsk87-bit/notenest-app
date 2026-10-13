/// Note kinds supported by NoteNest (Spec §4).
enum NoteType {
  text,
  checklist,
  image,
  voice,
  drawing,
  link;

  static NoteType fromIndex(int index) {
    if (index < 0 || index >= NoteType.values.length) return NoteType.text;
    return NoteType.values[index];
  }

  String get key => name;

  String get label {
    switch (this) {
      case NoteType.text:
        return 'Text';
      case NoteType.checklist:
        return 'Checklist';
      case NoteType.image:
        return 'Image';
      case NoteType.voice:
        return 'Voice';
      case NoteType.drawing:
        return 'Drawing';
      case NoteType.link:
        return 'Link';
    }
  }
}

/// Attachment kinds stored for a note.
enum AttachmentType {
  image,
  audio,
  drawing,
  file;

  static AttachmentType fromIndex(int index) {
    if (index < 0 || index >= AttachmentType.values.length) {
      return AttachmentType.file;
    }
    return AttachmentType.values[index];
  }
}

/// Sort orders offered on the home screen (Spec §5).
enum NoteSort { updatedDesc, createdDesc, titleAsc }

extension NoteSortX on NoteSort {
  String get label {
    switch (this) {
      case NoteSort.updatedDesc:
        return 'Recently edited';
      case NoteSort.createdDesc:
        return 'Date created';
      case NoteSort.titleAsc:
        return 'Title (A–Z)';
    }
  }
}

/// Grid or list layout (Spec §3).
enum LayoutMode { grid, list }
