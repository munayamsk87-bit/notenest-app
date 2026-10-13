import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/models/label.dart';
import '../data/repositories/label_repository.dart';
import '../data/repositories/note_repository.dart';

/// Manages user labels and their note counts (Spec §5).
class LabelsProvider extends ChangeNotifier {
  LabelsProvider(this._labels, this._notes);

  final LabelRepository _labels;
  final NoteRepository _notes;
  static const Uuid _uuid = Uuid();

  List<Label> _items = <Label>[];
  Map<String, int> _counts = <String, int>{};

  List<Label> get items => List<Label>.unmodifiable(_items);

  int countFor(String labelId) => _counts[labelId] ?? 0;

  Label? byId(String id) {
    for (final Label l in _items) {
      if (l.id == id) return l;
    }
    return null;
  }

  Future<void> load() async {
    _items = await _labels.getAll();
    _counts = await _notes.labelCounts();
    notifyListeners();
  }

  Future<Label> create(String name, {int color = 0}) async {
    final Label label = Label(id: _uuid.v4(), name: name.trim(), color: color);
    await _labels.insert(label);
    await load();
    return label;
  }

  Future<void> rename(String id, String name) async {
    final Label? existing = byId(id);
    if (existing == null) return;
    await _labels.update(existing.copyWith(name: name.trim()));
    await load();
  }

  Future<void> setColor(String id, int color) async {
    final Label? existing = byId(id);
    if (existing == null) return;
    await _labels.update(existing.copyWith(color: color));
    await load();
  }

  Future<void> delete(String id) async {
    await _labels.delete(id);
    await load();
  }
}
