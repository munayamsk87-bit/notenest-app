/// A user-created label (Spec §5). A note can carry several.
class Label {
  final String id;
  String name;
  int color;

  Label({required this.id, required this.name, this.color = 0});

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'color': color,
      };

  factory Label.fromMap(Map<String, Object?> map) => Label(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? '',
        color: (map['color'] as int?) ?? 0,
      );

  Label copyWith({String? name, int? color}) =>
      Label(id: id, name: name ?? this.name, color: color ?? this.color);
}
