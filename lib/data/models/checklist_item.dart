/// One row of a checklist note (Spec §4B).
class ChecklistItem {
  final String id;
  final String noteId;
  String text;
  bool isDone;
  int position;

  ChecklistItem({
    required this.id,
    required this.noteId,
    this.text = '',
    this.isDone = false,
    this.position = 0,
  });

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'noteId': noteId,
        'text': text,
        'isDone': isDone ? 1 : 0,
        'position': position,
      };

  factory ChecklistItem.fromMap(Map<String, Object?> map) => ChecklistItem(
        id: map['id'] as String,
        noteId: map['noteId'] as String,
        text: (map['text'] as String?) ?? '',
        isDone: (map['isDone'] as int?) == 1,
        position: (map['position'] as int?) ?? 0,
      );

  ChecklistItem copyWith({String? text, bool? isDone, int? position}) =>
      ChecklistItem(
        id: id,
        noteId: noteId,
        text: text ?? this.text,
        isDone: isDone ?? this.isDone,
        position: position ?? this.position,
      );
}
