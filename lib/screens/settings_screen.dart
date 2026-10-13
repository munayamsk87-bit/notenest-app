import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_info.dart';
import '../core/l10n/context_ext.dart';
import '../core/theme/app_colors.dart';
import '../data/db/database_helper.dart';
import '../data/services/app_lock_service.dart';
import '../data/services/file_storage_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/settings_service.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/note_color_picker.dart';

/// Fully functional settings screen (Spec §12, §13 screen 15).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _aiKeyController = TextEditingController();
  bool _aiKeyLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAiKey();
  }

  Future<void> _loadAiKey() async {
    final String? key = await SettingsService.instance.aiApiKey();
    if (!mounted) return;
    setState(() {
      _aiKeyController.text = key ?? '';
      _aiKeyLoaded = true;
    });
  }

  @override
  void dispose() {
    _aiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final NotesProvider notes = context.watch<NotesProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          _section(context.t('appearance')),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(context.t('theme')),
            subtitle: Text(_themeModeLabel(settings.themeMode)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickThemeMode(settings),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.t('themePack')),
            subtitle: Text(settings.themePack.label),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickThemePack(settings),
          ),
          ListTile(
            leading: const Icon(Icons.grid_view_rounded),
            title: Text(context.t('defaultLayout')),
            subtitle: Text(settings.layout == LayoutModeValue.grid
                ? context.t('gridView')
                : context.t('listView')),
            onTap: settings.toggleLayout,
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(context.t('language')),
            subtitle: Text(settings.locale.languageCode == 'bn'
                ? context.t('bengali')
                : context.t('english')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickLanguage(settings),
          ),
          ListTile(
            leading: const Icon(Icons.format_color_fill_rounded),
            title: Text(context.t('defaultColor')),
            onTap: () => _pickDefaultColor(settings),
            trailing: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: NoteColors.byValue(settings.defaultColor).light,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
            ),
          ),

          _section(context.t('settings')),
          SwitchListTile(
            secondary: const Icon(Icons.playlist_add_check_rounded),
            title: Text(context.t('moveCompletedToBottom')),
            value: settings.moveCompletedToBottom,
            onChanged: settings.setMoveCompletedToBottom,
          ),
          ListTile(
            leading: const Icon(Icons.save_outlined),
            title: Text(context.t('autoSaveSection')),
            subtitle: Text(context.t('autoSaveHint')),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(context.t('notifications')),
            subtitle: Text(context.t('notificationSettings')),
            onTap: () async {
              final bool granted =
                  await NotificationService.instance.requestPermissions();
              if (!mounted) return;
              if (!granted) context.showSnack(context.t('permissionNotifications'));
              await NotificationService.instance.requestExactAlarmPermission();
            },
          ),

          _section(context.t('data')),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(context.t('backupRestore')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pushNamed('/backup'),
          ),
          FutureBuilder<int>(
            future: FileStorageService.instance.attachmentsSize(),
            builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
              final String size = snapshot.hasData
                  ? FileStorageService.humanSize(snapshot.data!)
                  : '…';
              return ListTile(
                leading: const Icon(Icons.storage_rounded),
                title: Text(context.t('storageUsage')),
                subtitle: Text(context.t('storageUsedBy', <String, Object>{
                  'notes': notes.activeCount,
                  'files': notes.attachmentCountSnapshot,
                })),
                trailing: Text(size),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.search_off_rounded),
            title: Text(context.t('clearSearchHistory')),
            onTap: () async {
              await notes.clearSearchHistory();
              if (mounted) context.showSnack(context.t('saved'));
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined,
                color: context.scheme.error),
            title: Text(context.t('clearLocalData')),
            onTap: () => _clearLocalData(),
          ),

          _section(context.t('privacy')),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline_rounded),
            title: Text(context.t('appLock')),
            subtitle: Text(context.t('appLockHint')),
            value: settings.appLockEnabled,
            onChanged: (bool value) => _toggleAppLock(settings, value),
          ),

          _section(context.t('account')),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(settings.guestMode
                ? context.t('guestMode')
                : (settings.accountEmail ?? context.t('signIn'))),
            subtitle: Text(context.t('syncNotConfigured')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pushNamed('/signin'),
          ),

          _section(context.t('aiTools')),
          if (_aiKeyLoaded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                controller: _aiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.t('aiApiKey'),
                  helperText: context.t('aiApiKeyHint'),
                ),
                onSubmitted: (String value) =>
                    SettingsService.instance.setAiApiKey(value),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await SettingsService.instance
                          .setAiApiKey(_aiKeyController.text);
                      if (mounted) context.showSnack(context.t('saved'));
                    },
                    child: Text(context.t('save')),
                  ),
                ),
              ],
            ),
          ),

          _section(context.t('about')),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(context.t('about')),
            onTap: () => Navigator.of(context).pushNamed('/about'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(context.t('privacy')),
            onTap: () => Navigator.of(context).pushNamed('/about'),
          ),
          ListTile(
            leading: const Icon(Icons.tag_rounded),
            title: Text(context.t('appVersion')),
            trailing: Text(AppInfo.versionLabel),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.scheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return context.t('themeSystem');
      case ThemeMode.light:
        return context.t('themeLight');
      case ThemeMode.dark:
        return context.t('themeDark');
    }
  }

  Future<void> _pickThemeMode(SettingsProvider settings) async {
    final ThemeMode? mode = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final ThemeMode mode in ThemeMode.values)
              RadioListTile<ThemeMode>(
                value: mode,
                groupValue: settings.themeMode,
                onChanged: (ThemeMode? v) => Navigator.of(ctx).pop(v),
                title: Text(_themeModeLabel(mode)),
              ),
          ],
        ),
      ),
    );
    if (mode != null) await settings.setThemeMode(mode);
  }

  Future<void> _pickThemePack(SettingsProvider settings) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final ThemePack pack in ThemePack.values)
              RadioListTile<ThemePack>(
                value: pack,
                groupValue: settings.themePack,
                onChanged: (ThemePack? v) {
                  Navigator.of(ctx).pop();
                  if (v != null) settings.setThemePack(v);
                },
                title: Text(pack.label),
                secondary: CircleAvatar(backgroundColor: pack.seed, radius: 12),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLanguage(SettingsProvider settings) async {
    final Locale? locale = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RadioListTile<String>(
              value: 'en',
              groupValue: settings.locale.languageCode,
              onChanged: (_) => Navigator.of(ctx).pop(const Locale('en')),
              title: Text(ctx.t('english')),
            ),
            RadioListTile<String>(
              value: 'bn',
              groupValue: settings.locale.languageCode,
              onChanged: (_) => Navigator.of(ctx).pop(const Locale('bn')),
              title: Text(ctx.t('bengali')),
            ),
          ],
        ),
      ),
    );
    if (locale != null) await settings.setLocale(locale);
  }

  Future<void> _pickDefaultColor(SettingsProvider settings) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            NoteColorPicker(
              selected: settings.defaultColor,
              onSelected: (int v) {
                Navigator.of(ctx).pop();
                settings.setDefaultColor(v);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAppLock(SettingsProvider settings, bool value) async {
    if (value) {
      final bool supported = await AppLockService.instance.isSupported();
      if (!supported) {
        if (mounted) context.showSnack(context.t('somethingWentWrong'));
        return;
      }
      final bool ok = await AppLockService.instance
          .authenticate(reason: context.t('unlockReason'));
      if (!ok) return;
    }
    await settings.setAppLockEnabled(value);
  }

  Future<void> _clearLocalData() async {
    final bool ok = await showConfirmDialog(
      context,
      title: context.t('confirmClearDataTitle'),
      body: context.t('confirmClearDataBody'),
      confirmLabel: context.t('clearLocalData'),
      cancelLabel: context.t('cancel'),
      destructive: true,
    );
    if (!ok) return;
    await DatabaseHelper.instance.wipe();
    await NotificationService.instance.cancelAll();
    if (!mounted) return;
    await context.read<NotesProvider>().refresh();
    if (mounted) context.showSnack(context.t('saved'));
  }
}
