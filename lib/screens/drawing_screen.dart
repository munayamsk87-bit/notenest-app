import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/enums.dart';
import '../core/l10n/context_ext.dart';
import '../data/models/attachment.dart';
import '../data/models/note.dart';
import '../data/services/file_storage_service.dart';
import '../providers/notes_provider.dart';

/// A single freehand stroke on the drawing canvas.
class _Stroke {
  _Stroke({required this.color, required this.width, required this.erase});
  final Color color;
  final double width;
  final bool erase;
  final List<Offset> points = <Offset>[];
}

/// Simple drawing canvas with pen colours, width, eraser, undo/redo, clear and
/// save-as-image (Spec §4E).
class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  static const Uuid _uuid = Uuid();

  final GlobalKey _boundaryKey = GlobalKey();
  final List<_Stroke> _strokes = <_Stroke>[];
  final List<_Stroke> _redo = <_Stroke>[];

  Color _color = const Color(0xFF292638);
  double _width = 4;
  bool _erase = false;
  _Stroke? _current;

  static const List<Color> _palette = <Color>[
    Color(0xFF292638),
    Color(0xFF8060C7),
    Color(0xFFE0709A),
    Color(0xFF4FB286),
    Color(0xFF5B9BD5),
    Color(0xFFE0A800),
  ];

  void _start(DragStartDetails details) {
    setState(() {
      _current = _Stroke(color: _color, width: _width, erase: _erase)
        ..points.add(details.localPosition);
      _strokes.add(_current!);
      _redo.clear();
    });
  }

  void _update(DragUpdateDetails details) {
    setState(() => _current?.points.add(details.localPosition));
  }

  void _end(DragEndDetails details) {
    setState(() => _current = null);
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redo.add(_strokes.removeLast()));
  }

  void _redoStroke() {
    if (_redo.isEmpty) return;
    setState(() => _strokes.add(_redo.removeLast()));
  }

  void _clear() => setState(() {
        _strokes.clear();
        _redo.clear();
      });

  Future<void> _save(Note note) async {
    try {
      final RenderRepaintBoundary boundary = _boundaryKey.currentContext!
          .findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final String path = await FileStorageService.instance
          .persistBytes(data.buffer.asUint8List(), extension: 'png');
      await context.read<NotesProvider>().addAttachment(
            Attachment(
              id: _uuid.v4(),
              noteId: note.id,
              type: AttachmentType.drawing,
              path: path,
              mimeType: 'image/png',
            ),
          );
      if (!mounted) return;
      context.showSnack(context.t('saved'));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) context.showSnack(context.t('somethingWentWrong'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final NotesProvider notes = context.watch<NotesProvider>();
    final Note? note = notes.byId(widget.noteId);
    if (note == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('drawing')),
        actions: <Widget>[
          IconButton(
            tooltip: context.t('undo'),
            icon: const Icon(Icons.undo_rounded),
            onPressed: _undo,
          ),
          IconButton(
            tooltip: context.t('redo'),
            icon: const Icon(Icons.redo_rounded),
            onPressed: _redoStroke,
          ),
          IconButton(
            tooltip: context.t('clear'),
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clear,
          ),
          IconButton(
            tooltip: context.t('saveDrawing'),
            icon: const Icon(Icons.check_rounded),
            onPressed: () => _save(note),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                color: Colors.white,
                child: GestureDetector(
                  onPanStart: _start,
                  onPanUpdate: _update,
                  onPanEnd: _end,
                  child: CustomPaint(
                    painter: _DrawingPainter(_strokes),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          _toolbar(context),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                for (final Color c in _palette)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _color = c;
                        _erase = false;
                      }),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (!_erase && _color == c)
                                ? context.scheme.primary
                                : Colors.black12,
                            width: (!_erase && _color == c) ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: () => setState(() => _erase = !_erase),
                  icon: Icon(_erase ? Icons.edit_rounded : Icons.cleaning_services_outlined),
                  tooltip: context.t('eraser'),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                const Icon(Icons.line_weight_rounded, size: 18),
                Expanded(
                  child: Slider(
                    value: _width,
                    min: 1,
                    max: 24,
                    onChanged: (double v) => setState(() => _width = v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter(this.strokes);
  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _Stroke stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final Paint paint = Paint()
        ..color = stroke.erase ? Colors.white : stroke.color
        ..strokeWidth = stroke.erase ? stroke.width * 2.5 : stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, paint.strokeWidth / 2, paint);
        continue;
      }
      final Path path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) => true;
}
