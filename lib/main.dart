import 'package:flutter/material.dart';

import 'app.dart';
import 'data/db/database_helper.dart';
import 'data/services/notification_service.dart';
import 'data/services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferences first, then the database so migrations run before first paint.
  await SettingsService.instance.init();
  await DatabaseHelper.instance.database;

  // Prepare the notification channel + timezone before the UI needs it.
  await NotificationService.instance.init();

  runApp(const NoteNestApp());
}
