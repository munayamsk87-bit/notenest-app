import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/context_ext.dart';
import '../data/models/note.dart';
import '../data/services/ai_service.dart';
import '../providers/notes_provider.dart';
import '../widgets/mascot.dart';

class _Msg {
  _Msg(this.text, {required this.fromUser});
  final String text;
  final bool fromUser;
}

/// "Ask AI about this note" — a tiny chat whose context is the open note.
class AiAskScreen extends StatefulWidget {
  const AiAskScreen({super.key, required this.noteId});

  final String noteId;

  @override
  State<AiAskScreen> createState() => _AiAskScreenState();
}

class _AiAskScreenState extends State<AiAskScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _messages = <_Msg>[];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String question = _controller.text.trim();
    if (question.isEmpty || _sending) return;

    final NotesProvider notes = context.read<NotesProvider>();
    final Note? note = notes.byId(widget.noteId);
    if (note == null) return;

    setState(() {
      _messages.add(_Msg(question, fromUser: true));
      _sending = true;
    });
    _controller.clear();
    _scrollToEnd();

    final String context_ = '${note.title}\n${note.body}'.trim();
    try {
      final String answer = await AiService.instance.ask(question, context_);
      if (!mounted) return;
      setState(() => _messages.add(_Msg(answer, fromUser: false)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_Msg('$e', fromUser: false)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final NotesProvider notes = context.watch<NotesProvider>();
    final Note? note = notes.byId(widget.noteId);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('aiAskTitle')),
        actions: <Widget>[
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: context.t('clear'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => setState(_messages.clear),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: context.scheme.primary.withOpacity(0.06),
            child: Text(
              note?.displayTitle ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? _empty(context)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (BuildContext context, int index) =>
                        _bubble(context, _messages[index]),
                  ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(hintText: context.t('aiAskHint')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Mascot(size: 132, bob: false),
            const SizedBox(height: 16),
            Text(
              context.t('aiAskTitle'),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.t('aiAskHint'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, _Msg msg) {
    final bool mine = msg.fromUser;
    final Color bg = mine
        ? context.scheme.primary
        : context.scheme.primary.withOpacity(context.isDark ? 0.18 : 0.10);
    final Color fg = mine ? Colors.white : null;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: SelectableText(
          msg.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
        ),
      ),
    );
  }
}
