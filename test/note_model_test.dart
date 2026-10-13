import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/core/constants/enums.dart';
import 'package:notenest/data/models/note.dart';

void main() {
  group('Note serialisation', () {
    test('round-trips through toMap/fromMap without losing fields', () {
      final Note note = Note(
        id: 'n1',
        title: 'Groceries',
        body: 'milk, eggs',
        type: NoteType.checklist,
        color: 3,
        isPinned: true,
        isFavorite: true,
        reminderAt: DateTime(2026, 3, 14, 9, 30),
        recurrence: ReminderRecurrence.weekly,
      );

      final Note restored = Note.fromMap(note.toMap());

      expect(restored.id, 'n1');
      expect(restored.title, 'Groceries');
      expect(restored.type, NoteType.checklist);
      expect(restored.color, 3);
      expect(restored.isPinned, isTrue);
      expect(restored.isFavorite, isTrue);
      expect(restored.recurrence, ReminderRecurrence.weekly);
      expect(restored.reminderAt, DateTime(2026, 3, 14, 9, 30));
    });

    test('displayTitle falls back for empty titles', () {
      final Note note = Note(id: 'n2');
      expect(note.displayTitle, 'Untitled note');
    });

    test('searchableText is lower-cased title + body', () {
      final Note note = Note(id: 'n3', title: 'Hello', body: 'World');
      expect(note.searchableText, 'hello\nworld');
    });
  });
}
