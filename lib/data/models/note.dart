import '../../core/constants/enums.dart';

/// A single note of any supported type (Spec §4). Attachments and checklist
/// items live in their own tables and are joined by [id].
class Note {
  final String id;
  String title;
  String body;
  NoteType type;
  int color;
  bool isPinned;
  bool isFavorite;
  bool isArchived;
  bool isTrashed;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? trashedAt;

  // Reminder (Spec §6)
  DateTime? reminderAt;
  ReminderRecurrence recurrence;
  int? notificationId;

  // Link notes (Spec §4F)
  String? linkUrl;

  Note({
    required this.id,
    this.title = '',
    this.body = '',
    this.type = NoteType.text,
    this.color = 0,
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.isTrashed = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.trashedAt,
    this.reminderAt,
    this.recurrence = ReminderRecurrence.none,
    this.notificationId,
    this.linkUrl,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get hasReminder => reminderAt != null;

  /// The text used for search + previews.
  String get searchableText => '$title\n$body'.toLowerCase();

  String get displayTitle =>
      title.trim().isEmpty ? 'Untitled note' : title.trim();

  String get preview {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.length > 140 ? '${trimmed.substring(0, 140)}…' : trimmed;
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'body': body,
        'type': type.index,
        'color': color,
        'isPinned': isPinned ? 1 : 0,
        'isFavorite': isFavorite ? 1 : 0,
        'isArchived': isArchived ? 1 : 0,
        'isTrashed': isTrashed ? 1 : 0,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'trashedAt': trashedAt?.millisecondsSinceEpoch,
        'reminderAt': reminderAt?.millisecondsSinceEpoch,
        'recurrence': recurrence.name,
        'notificationId': notificationId,
        'linkUrl': linkUrl,
      };

  factory Note.fromMap(Map<String, Object?> map) => Note(
        id: map['id'] as String,
        title: (map['title'] as String?) ?? '',
        body: (map['body'] as String?) ?? '',
        type: NoteType.fromIndex((map['type'] as int?) ?? 0),
        color: (map['color'] as int?) ?? 0,
        isPinned: (map['isPinned'] as int?) == 1,
        isFavorite: (map['isFavorite'] as int?) == 1,
        isArchived: (map['isArchived'] as int?) == 1,
        isTrashed: (map['isTrashed'] as int?) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (map['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
        trashedAt: (map['trashedAt'] as int?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['trashedAt'] as int),
        reminderAt: (map['reminderAt'] as int?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['reminderAt'] as int),
        recurrence: ReminderRecurrence.fromName(map['recurrence'] as String?),
        notificationId: map['notificationId'] as int?,
        linkUrl: map['linkUrl'] as String?,
      );

  Note copyWith({
    String? title,
    String? body,
    NoteType? type,
    int? color,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    bool? isTrashed,
    DateTime? updatedAt,
    DateTime? trashedAt,
    bool clearTrashedAt = false,
    DateTime? reminderAt,
    bool clearReminder = false,
    ReminderRecurrence? recurrence,
    int? notificationId,
    bool clearNotificationId = false,
    String? linkUrl,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isTrashed: isTrashed ?? this.isTrashed,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trashedAt: clearTrashedAt ? null : (trashedAt ?? this.trashedAt),
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
      recurrence: recurrence ?? this.recurrence,
      notificationId:
          clearNotificationId ? null : (notificationId ?? this.notificationId),
      linkUrl: linkUrl ?? this.linkUrl,
    );
  }
}

/// Repeat behaviour for reminders (Spec §6 "recurring reminders if supported").
enum ReminderRecurrence {
  none,
  daily,
  weekly;

  static ReminderRecurrence fromName(String? name) {
    return ReminderRecurrence.values.firstWhere(
      (ReminderRecurrence r) => r.name == name,
      orElse: () => ReminderRecurrence.none,
    );
  }
}
