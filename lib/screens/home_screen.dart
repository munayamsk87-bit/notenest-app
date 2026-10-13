import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/enums.dart';
import '../core/l10n/context_ext.dart';
import '../widgets/animated_appear.dart';
import '../widgets/bouncy_fab.dart';
import '../widgets/floating_blobs.dart';
import '../widgets/mascot.dart';
import '../data/models/attachment.dart';
import '../data/models/label.dart';
import '../data/models/note.dart';
import '../providers/labels_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/note_card.dart';
import '../widgets/section_header.dart';

/// Home screen: greeting, search, pinned + recent sections, filters, grid/list
/// toggle and quick creation (Spec §3).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  NoteSort _sort = NoteSort.updatedDesc;
  NoteType? _typeFilter;
  String? _labelFilter;
  final Set<String> _selected = <String>{};
  bool _selectionMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _greeting(BuildContext context) {
    final int hour = DateTime.now().hour;
    if (hour < 12) return context.t('greetingMorning');
    if (hour < 17) return context.t('greetingAfternoon');
    return context.t('greetingEvening');
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _toggleSelected(Note note) {
    setState(() {
      if (_selected.contains(note.id)) {
        _selected.remove(note.id);
        if (_selected.isEmpty) _selectionMode = false;
      } else {
        _selected.add(note.id);
      }
    });
  }

  Future<void> _openNote(Note note) async {
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

  Future<void> _quickCreate() async {
    final SettingsProvider settings = context.read<SettingsProvider>();
    final NoteType? type = await showModalBottomSheet<NoteType>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                ctx.t('quickCreate'),
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            AnimatedAppear(index: 0, child: _createTile(ctx, Icons.notes_rounded, ctx.t('textNote'), NoteType.text)),
            AnimatedAppear(index: 1, child: _createTile(ctx, Icons.checklist_rounded, ctx.t('checklist'), NoteType.checklist)),
            AnimatedAppear(index: 2, child: _createTile(ctx, Icons.image_rounded, ctx.t('image'), NoteType.image)),
            AnimatedAppear(index: 3, child: _createTile(ctx, Icons.mic_rounded, ctx.t('voice'), NoteType.voice)),
            AnimatedAppear(index: 4, child: _createTile(ctx, Icons.brush_rounded, ctx.t('drawing'), NoteType.drawing)),
            AnimatedAppear(index: 5, child: _createTile(ctx, Icons.link_rounded, ctx.t('link'), NoteType.link)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    final NotesProvider notes = context.read<NotesProvider>();
    final Note note =
        await notes.create(type: type, color: settings.defaultColor);
    if (!mounted) return;
    await _openNote(note);
  }

  Widget _createTile(
      BuildContext ctx, IconData icon, String label, NoteType type) {
    return ListTile(
      leading: Icon(icon, color: ctx.scheme.primary),
      title: Text(label),
      onTap: () => Navigator.of(ctx).pop(type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final NotesProvider notes = context.watch<NotesProvider>();
    final LabelsProvider labels = context.watch<LabelsProvider>();
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final bool isGrid = settings.layout == LayoutModeValue.grid;

    final List<Note> pinned = _applyTypeFilter(notes.pinned(_sort));
    List<Note> unpinned = _applyTypeFilter(notes.unpinned(_sort));
    if (_labelFilter != null) {
      final List<Note> labelled = notes.byLabel(_labelFilter!, _sort);
      unpinned = _applyTypeFilter(labelled.where((Note n) => !n.isPinned).toList());
    }

    return Scaffold(
      appBar: _selectionMode
          ? _selectionAppBar(notes)
          : AppBar(
              titleSpacing: 16,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const MascotAvatar(size: 44),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_greeting(context),
                          style: Theme.of(context).textTheme.labelMedium),
                      Text(
                        context.t('appName'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: context.t(isGrid ? 'listView' : 'gridView'),
                  icon: Icon(isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded),
                  onPressed: settings.toggleLayout,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (String value) {
                    switch (value) {
                      case 'labels':
                        Navigator.of(context).pushNamed('/labels');
                        break;
                      case 'reminders':
                        Navigator.of(context).pushNamed('/reminders');
                        break;
                      case 'archive':
                        Navigator.of(context).pushNamed('/archive');
                        break;
                      case 'trash':
                        Navigator.of(context).pushNamed('/trash');
                        break;
                      case 'backup':
                        Navigator.of(context).pushNamed('/backup');
                        break;
                      case 'settings':
                        Navigator.of(context).pushNamed('/settings');
                        break;
                      case 'about':
                        Navigator.of(context).pushNamed('/about');
                        break;
                    }
                  },
                  itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                        value: 'labels',
                        child: ListTile(
                            leading: const Icon(Icons.label_outline_rounded),
                            title: Text(ctx.t('labels')))),
                    PopupMenuItem<String>(
                        value: 'reminders',
                        child: ListTile(
                            leading: const Icon(Icons.alarm_rounded),
                            title: Text(ctx.t('reminders')))),
                    PopupMenuItem<String>(
                        value: 'archive',
                        child: ListTile(
                            leading: const Icon(Icons.archive_outlined),
                            title: Text(ctx.t('archive')))),
                    PopupMenuItem<String>(
                        value: 'trash',
                        child: ListTile(
                            leading: const Icon(Icons.delete_outline_rounded),
                            title: Text(ctx.t('trash')))),
                    PopupMenuItem<String>(
                        value: 'backup',
                        child: ListTile(
                            leading: const Icon(Icons.backup_outlined),
                            title: Text(ctx.t('backupRestore')))),
                    PopupMenuItem<String>(
                        value: 'settings',
                        child: ListTile(
                            leading: const Icon(Icons.settings_outlined),
                            title: Text(ctx.t('settings')))),
                    PopupMenuItem<String>(
                        value: 'about',
                        child: ListTile(
                            leading: const Icon(Icons.info_outline_rounded),
                            title: Text(ctx.t('about')))),
                  ],
                ),
              ],
            ),
      floatingActionButton: BouncyFab(
        onTap: _quickCreate,
        label: context.t('newNote'),
      ),
      body: FloatingBlobs(
        child: notes.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => notes.refresh(),
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(child: _searchBar()),
                  SliverToBoxAdapter(child: _filterRow(labels)),
                  if (notes.activeCount == 0 && pinned.isEmpty && unpinned.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.auto_stories_rounded,
                        imageAsset: 'assets/mascot/mascot.png',
                        title: context.t('emptyTitle'),
                        body: context.t('emptyBody'),
                        actionLabel: context.t('createFirstNote'),
                        onAction: _quickCreate,
                      ),
                    )
                  else ...<Widget>[
                    if (pinned.isNotEmpty) ...<Widget>[
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          title: context.t('pinned'),
                          icon: Icons.push_pin_rounded,
                        ),
                      ),
                      _notesSliver(pinned, notes, labels, isGrid),
                    ],
                    SliverToBoxAdapter(
                      child: SectionHeader(
                        title: _labelFilter != null
                            ? (labels.byId(_labelFilter!)?.name ?? context.t('allNotes'))
                            : context.t('recent'),
                        icon: Icons.schedule_rounded,
                        trailing: context.t('noteCount',
                            <String, Object>{'n': unpinned.length}),
                      ),
                    ),
                    if (unpinned.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            context.t('emptySearchBody'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      _notesSliver(unpinned, notes, labels, isGrid),
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ],
              ),
            ),
      ),
    );
  }

  List<Note> _applyTypeFilter(List<Note> input) {
    if (_typeFilter == null) return input;
    return input.where((Note n) => n.type == _typeFilter).toList();
  }

  Widget _notesSliver(List<Note> notes, NotesProvider provider,
      LabelsProvider labels, bool isGrid) {
    if (isGrid) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 208,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) => AnimatedAppear(
              index: index,
              child: _card(notes[index], provider, labels, true),
            ),
            childCount: notes.length,
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) => AnimatedAppear(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _card(notes[index], provider, labels, false),
            ),
          ),
          childCount: notes.length,
        ),
      ),
    );
  }

  Widget _card(Note note, NotesProvider provider, LabelsProvider labels, bool isGrid) {
    final (int done, int total) = provider.checklistProgress(note.id);
    final List<Label> noteLabels = provider
        .labelIdsFor(note.id)
        .map((String id) => labels.byId(id))
        .whereType<Label>()
        .toList();
    final List<Attachment> attachments = provider.attachmentsFor(note.id);
    return NoteCard(
      note: note,
      done: done,
      total: total,
      attachments: attachments,
      labels: noteLabels,
      isGrid: isGrid,
      selected: _selected.contains(note.id),
      selectionMode: _selectionMode,
      onTap: () {
        if (_selectionMode) {
          _toggleSelected(note);
        } else {
          _openNote(note);
        }
      },
      onLongPress: () {
        if (_selectionMode) {
          _toggleSelected(note);
        } else {
          setState(() {
            _selectionMode = true;
            _selected.add(note.id);
          });
        }
      },
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed('/search'),
        child: AbsorbPointer(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.t('searchNotes'),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterRow(LabelsProvider labels) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: <Widget>[
          _filterChip(
            label: context.t('allTypes'),
            selected: _typeFilter == null,
            onTap: () => setState(() => _typeFilter = null),
          ),
          for (final NoteType type in NoteType.values)
            _filterChip(
              label: type.label,
              selected: _typeFilter == type,
              onTap: () => setState(
                  () => _typeFilter = _typeFilter == type ? null : type),
            ),
          const VerticalDivider(width: 20),
          for (final Label label in labels.items)
            _filterChip(
              label: label.name,
              selected: _labelFilter == label.id,
              onTap: () => setState(() =>
                  _labelFilter = _labelFilter == label.id ? null : label.id),
            ),
          const SizedBox(width: 8),
          PopupMenuButton<NoteSort>(
            icon: const Icon(Icons.sort_rounded, size: 20),
            onSelected: (NoteSort sort) => setState(() => _sort = sort),
            itemBuilder: (BuildContext ctx) => NoteSort.values
                .map((NoteSort s) => PopupMenuItem<NoteSort>(
                      value: s,
                      child: Text(s.label),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  AppBar _selectionAppBar(NotesProvider notes) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _exitSelection,
      ),
      title: Text(context.t('selectedCount', <String, Object>{'n': _selected.length})),
      actions: <Widget>[
        IconButton(
          tooltip: context.t('selectAll'),
          icon: const Icon(Icons.select_all_rounded),
          onPressed: () {
            setState(() {
              for (final Note n in <Note>[...notes.pinned(_sort), ...notes.unpinned(_sort)]) {
                _selected.add(n.id);
              }
            });
          },
        ),
        IconButton(
          tooltip: context.t('archiveAction'),
          icon: const Icon(Icons.archive_outlined),
          onPressed: () async {
            await notes.bulkArchive(_selected.toList());
            _exitSelection();
          },
        ),
        IconButton(
          tooltip: context.t('moveToTrash'),
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () async {
            await notes.bulkTrash(_selected.toList());
            _exitSelection();
          },
        ),
      ],
    );
  }
}
