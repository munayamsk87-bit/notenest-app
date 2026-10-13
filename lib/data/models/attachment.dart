import '../../core/constants/enums.dart';

/// A file attached to a note — image, audio, drawing or generic file.
/// Files are copied into app-private storage so they survive gallery cleanup.
class Attachment {
  final String id;
  final String noteId;
  AttachmentType type;
  String path;
  String? mimeType;
  int? durationMs;
  final DateTime createdAt;

  Attachment({
    required this.id,
    required this.noteId,
    required this.type,
    required this.path,
    this.mimeType,
    this.durationMs,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'noteId': noteId,
        'type': type.index,
        'path': path,
        'mimeType': mimeType,
        'durationMs': durationMs,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Attachment.fromMap(Map<String, Object?> map) => Attachment(
        id: map['id'] as String,
        noteId: map['noteId'] as String,
        type: AttachmentType.fromIndex((map['type'] as int?) ?? 3),
        path: (map['path'] as String?) ?? '',
        mimeType: map['mimeType'] as String?,
        durationMs: map['durationMs'] as int?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      );
}
