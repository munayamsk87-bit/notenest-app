import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/context_ext.dart';
import '../data/services/backup_service.dart';
import '../data/services/file_storage_service.dart';
import '../providers/notes_provider.dart';

/// Backup & restore screen (Spec §10, §13 screen 14).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String? _status;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final BackupSummary summary = await BackupService.instance.exportBackup();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '${context.t('backupCreated')} · '
            '${context.t('noteCount', <String, Object>{'n': summary.notes})}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '${context.t('backupFailed')}: $e';
      });
    }
  }

  Future<void> _restore() async {
    final File? file = await BackupService.instance.pickBackup();
    if (file == null || !mounted) return;

    BackupSummary summary;
    try {
      summary = await BackupService.instance.validate(file);
    } catch (e) {
      if (mounted) context.showSnack('${context.t('importInvalid')} ($e)',
          error: true);
      return;
    }
    if (!mounted) return;

    final bool? replace = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(ctx.t('importModeTitle')),
        content: Text(
          '${ctx.t('importModeBody')}\n\n'
          '${ctx.t('noteCount', <String, Object>{'n': summary.notes})}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(ctx.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.t('merge')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.t('replace')),
          ),
        ],
      ),
    );
    if (replace == null || !mounted) return;

    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await BackupService.instance.restore(file, replace: replace);
      await context.read<NotesProvider>().refresh();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = context.t('backupRestored');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '${context.t('restoreFailed')}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('backupRestore'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.cloud_upload_outlined,
                      color: context.scheme.primary),
                  title: Text(context.t('backupNotes')),
                  subtitle: Text(context.t('exportData')),
                  onTap: _busy ? null : _export,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.cloud_download_outlined,
                      color: context.scheme.primary),
                  title: Text(context.t('restoreNotes')),
                  subtitle: Text(context.t('importModeBody')),
                  onTap: _busy ? null : _restore,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_status != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_status!),
              ),
            ),
          const SizedBox(height: 16),
          FutureBuilder<int>(
            future: FileStorageService.instance.attachmentsSize(),
            builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
              final String size = snapshot.hasData
                  ? FileStorageService.humanSize(snapshot.data!)
                  : '…';
              return ListTile(
                leading: const Icon(Icons.storage_rounded),
                title: Text(context.t('storageUsage')),
                trailing: Text(size),
              );
            },
          ),
        ],
      ),
    );
  }
}
