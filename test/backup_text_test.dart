import 'package:flutter_test/flutter_test.dart';
import 'package:notenest/data/models/checklist_item.dart';
import 'package:notenest/data/models/label.dart';
import 'package:notenest/data/models/note.dart';
import 'package:notenest/data/services/backup_service.dart';

void main() {
  group('BackupService.noteAsText', () {
    test('renders a checklist note with tick boxes', () {
      final Note note = Note(id: 'n1', title: 'Trip', body: '');
      final List<ChecklistItem> items = <ChecklistItem>[
        ChecklistItem(id: 'c1', noteId: 'n1', text: 'Passport', isDone: true),
        ChecklistItem(id: 'c2', noteId: 'n1', text: 'Charger', isDone: false),
      ];
      final List<Label> labels = <Label>[
        Label(id: 'l1', name: 'Travel'),
      ];

      final String text = BackupService.instance.noteAsText(note, items, labels);

      expect(text, contains('Trip'));
      expect(text, contains('Labels: Travel'));
      expect(text, contains('[x] Passport'));
      expect(text, contains('[ ] Charger'));
    });
  });
}
