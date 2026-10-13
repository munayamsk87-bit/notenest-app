import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/enums.dart';
import '../core/l10n/context_ext.dart';
import '../core/utils/date_utils.dart';
import '../data/models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/empty_state.dart';

/// Instant full-text search across titles, bodies, checklist items and labels,
/// with history and match highlighting (Spec §7, §13 screen 4).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<Note> _results = <Note>[];
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(value));
  }

  Future<void> _run(String value) async {
    setState(() {
      _query = value;
      _searching = true;
    });
    if (value.trim().isEmpty) {
      setState(() {
        _results = <Note>[];
        _searching = false;
      });
      return;
    }
    final List<Note> results = await context.read<NotesProvider>().search(value);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<void> _open(Note note) async {
    switch (note.type) {
      case NoteType.checklist:
        await Navigator.of(context).pushNamed('/checklist', arguments: note.id);
        break;
      case NoteType.image:
        await Navigator.of(context).pushNamed('/image', arguments: note.id);
        break;
      case NoteType.voice:
        await Navigator.of(context).pushNamed('/voice', arguments: note.id);
        break;
      case NoteType.drawing:
        await Navigator.of(context).pushNamed('/drawing', arguments: note.id);
        break;
      case NoteType.text:
      case NoteType.link:
        await Navigator.of(context).pushNamed('/note', arguments: note.id);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final NotesProvider notes = context.watch<NotesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.t('searchHint'),
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: _onChanged,
          onSubmitted: _run,
        ),
        actions: <Widget>[
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                _run('');
              },
            ),
        ],
      ),
      body: _body(notes),
    );
  }

  Widget _body(NotesProvider notes) {
    if (_controller.text.trim().isEmpty) {
      return _history(notes);
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: context.t('emptySearchTitle'),
        body: context.t('emptySearchBody'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final Note note = _results[index];
        return Card(
          child: ListTile(
            title: _highlighted(note.displayTitle,
                Theme.of(context).textTheme.titleMedium),
            subtitle: note.preview.isEmpty
                ? Text(AppDateUtils.relative(note.updatedAt))
                : _highlighted(note.preview,
                    Theme.of(context).textTheme.bodyMedium),
            onTap: () => _open(note),
          ),
        );
      },
    );
  }

  Widget _history(NotesProvider notes) {
    if (notes.searchHistory.isEmpty) {
      return EmptyState(
        icon: Icons.search_rounded,
        title: context.t('searchNotes'),
        body: context.t('emptySearchBody'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(context.t('searchHistory'),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(
              onPressed: () => notes.clearSearchHistory(),
              child: Text(context.t('clearSearchHistory')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: notes.searchHistory
              .map((String term) => ActionChip(
                    label: Text(term),
                    onPressed: () {
                      _controller.text = term;
                      _run(term);
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _highlighted(String text, TextStyle? base) {
    final String query = _query.trim();
    if (query.isEmpty) return Text(text, style: base, maxLines: 2);
    final String lower = text.toLowerCase();
    final String q = query.toLowerCase();
    final List<TextSpan> spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final int index = lower.indexOf(q, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + q.length),
        style: TextStyle(
          backgroundColor: context.scheme.primary.withOpacity(0.22),
          fontWeight: FontWeight.w700,
        ),
      ));
      start = index + q.length;
    }
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: base, children: spans),
    );
  }
}
