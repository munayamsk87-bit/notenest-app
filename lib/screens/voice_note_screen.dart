import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/enums.dart';
import '../core/l10n/context_ext.dart';
import '../data/models/attachment.dart';
import '../data/models/note.dart';
import '../data/services/file_storage_service.dart';
import '../data/services/speech_service.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_actions_sheet.dart';

/// Voice note recorder/player with optional live transcription (Spec §4D).
class VoiceNoteScreen extends StatefulWidget {
  const VoiceNoteScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<VoiceNoteScreen> createState() => _VoiceNoteScreenState();
}

class _VoiceNoteScreenState extends State<VoiceNoteScreen> {
  static const Uuid _uuid = Uuid();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  final TextEditingController _titleController = TextEditingController();
  Timer? _ticker;
  Timer? _debounce;

  bool _recording = false;
  bool _paused = false;
  bool _transcribe = false;
  bool _hydrated = false;
  Duration _elapsed = Duration.zero;
  String? _playingId;
  String _liveTranscript = '';
  StreamSubscription<PlayerState>? _playerSub;

  @override
  void initState() {
    super.initState();
    _playerSub = _player.playerStateStream.listen((PlayerState state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() => _playingId = null);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _debounce?.cancel();
    _playerSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _scheduleTitleSave(Note note) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      note.title = _titleController.text;
      await context.read<NotesProvider>().update(note);
    });
  }

  Future<void> _startRecording(Note note) async {
    if (!await _recorder.hasPermission()) {
      if (mounted) context.showSnack(context.t('permissionMic'), error: true);
      return;
    }
    final Directory dir = await FileStorageService.instance.attachmentsDir();
    final String path = p.join(dir.path, '${_uuid.v4()}.m4a');
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: path,
    );
    setState(() {
      _recording = true;
      _paused = false;
      _elapsed = Duration.zero;
      _liveTranscript = '';
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused) setState(() => _elapsed += const Duration(seconds: 1));
    });

    if (_transcribe) {
      final bool started = await SpeechService.instance.start(
        onResult: (String text, bool isFinal) {
          if (mounted) setState(() => _liveTranscript = text);
        },
      );
      if (!started && mounted) {
        context.showSnack(context.t('transcriptionUnavailable'));
      }
    }
  }

  Future<void> _pauseResume() async {
    if (_paused) {
      await _recorder.resume();
    } else {
      await _recorder.pause();
    }
    setState(() => _paused = !_paused);
  }

  Future<void> _stopRecording(Note note) async {
    final String? path = await _recorder.stop();
    _ticker?.cancel();
    await SpeechService.instance.stop();
    setState(() {
      _recording = false;
      _paused = false;
    });
    if (path == null) return;
    await context.read<NotesProvider>().addAttachment(
          Attachment(
            id: _uuid.v4(),
            noteId: note.id,
            type: AttachmentType.audio,
            path: path,
            mimeType: 'audio/mp4',
            durationMs: _elapsed.inMilliseconds,
          ),
        );
    if (mounted) setState(() {});
    if (_liveTranscript.trim().isNotEmpty) {
      await _offerTranscript(note, _liveTranscript.trim());
    }
  }

  Future<void> _offerTranscript(Note note, String transcript) async {
    final bool? append = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(ctx.t('transcribe')),
        content: SingleChildScrollView(child: Text(transcript)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.t('notNow')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.t('confirm')),
          ),
        ],
      ),
    );
    if (append == true) {
      note.body = '${note.body}\n\n$transcript'.trim();
      await context.read<NotesProvider>().update(note);
      if (mounted) setState(() {});
    }
  }

  Future<void> _togglePlay(Attachment a) async {
    if (_playingId == a.id) {
      await _player.pause();
      setState(() => _playingId = null);
      return;
    }
    try {
      await _player.setFilePath(a.path);
      await _player.play();
      setState(() => _playingId = a.id);
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
    if (!_hydrated) {
      _titleController.text = note.title;
      _hydrated = true;
    }
    final List<Attachment> recordings = notes
        .attachmentsFor(note.id)
        .where((Attachment a) => a.type == AttachmentType.audio)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('voice')),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => showNoteActionsSheet(context, note),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _titleController,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: context.t('titleHint'),
              border: InputBorder.none,
              filled: false,
            ),
            onChanged: (_) => _scheduleTitleSave(note),
          ),
          const SizedBox(height: 8),
          _recorderCard(context, note),
          const SizedBox(height: 20),
          if (recordings.isEmpty)
            Text(context.t('emptyRemindersBody'),
                style: Theme.of(context).textTheme.bodyMedium)
          else
            ...recordings.map((Attachment a) => _recordingTile(context, note, a)),
        ],
      ),
    );
  }

  Widget _recorderCard(BuildContext context, Note note) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: <Widget>[
          Text(
            _format(_elapsed),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (!_recording)
                FilledButton.icon(
                  onPressed: () => _startRecording(note),
                  icon: const Icon(Icons.fiber_manual_record_rounded),
                  label: Text(context.t('record')),
                )
              else ...<Widget>[
                IconButton.filledTonal(
                  iconSize: 30,
                  onPressed: _pauseResume,
                  icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                ),
                const SizedBox(width: 16),
                IconButton.filled(
                  iconSize: 30,
                  onPressed: () => _stopRecording(note),
                  icon: const Icon(Icons.stop_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _transcribe,
            onChanged: (bool v) => setState(() => _transcribe = v),
            title: Text(context.t('transcribe')),
            contentPadding: EdgeInsets.zero,
          ),
          if (_recording && _transcribe && _liveTranscript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_liveTranscript,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _recordingTile(BuildContext context, Note note, Attachment a) {
    final bool playing = _playingId == a.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: IconButton.filledTonal(
          onPressed: () => _togglePlay(a),
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
        title: Text(_format(Duration(milliseconds: a.durationMs ?? 0))),
        subtitle: Text(context.t('createdAt', <String, Object>{
          'when': '${a.createdAt.day}/${a.createdAt.month}/${a.createdAt.year}',
        })),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () async {
            if (playing) {
              await _player.stop();
              setState(() => _playingId = null);
            }
            await context.read<NotesProvider>().removeAttachment(a.id);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  String _format(Duration d) {
    final String m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
