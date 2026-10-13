import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/note.dart';

/// Real Android reminders via local notifications (Spec §6).
///
/// Uses exact alarms when the platform allows them and silently falls back to
/// inexact scheduling otherwise — never fabricating a delivery.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String channelId = 'notenest_reminders';
  static const String channelName = 'Note reminders';
  static const String channelDescription =
      'Reminders you set on your notes in NoteNest.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  void Function(String noteId)? onSelectNote;

  Future<void> init({void Function(String noteId)? onSelectNote}) async {
    if (onSelectNote != null) this.onSelectNote = onSelectNote;
    if (_initialised) return;

    tzdata.initializeTimeZones();
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to whatever tz.local resolves to.
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings init =
        InitializationSettings(android: androidInit);

    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          this.onSelectNote?.call(payload);
        }
      },
    );

    _initialised = true;
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// True when the OS will honour exact alarms; false means we schedule
  /// inexactly (Android 12+ requires a user grant for SCHEDULE_EXACT_ALARM).
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? allowed = await android?.canScheduleExactNotifications();
    return allowed ?? false;
  }

  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  int _notificationIdFor(Note note) =>
      note.notificationId ?? (note.id.hashCode & 0x7fffffff);

  /// Schedules (or reschedules) the reminder for [note]. Returns the
  /// notification id used, or null when the note has no reminder.
  Future<int?> schedule(Note note) async {
    if (note.reminderAt == null) return null;
    await init();

    final int id = _notificationIdFor(note);
    await _plugin.cancel(id);

    final tz.TZDateTime scheduled = _nextInstance(note);
    final bool exact = await canScheduleExactAlarms();

    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(
          note.preview.isEmpty ? note.displayTitle : note.preview,
        ),
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        note.displayTitle,
        note.preview.isEmpty ? 'Reminder' : note.preview,
        scheduled,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: _matchComponents(note.recurrence),
        payload: note.id,
      );
    } catch (e) {
      // Some OEMs reject exact alarms outright — retry inexactly once.
      debugPrint('Exact schedule failed ($e); retrying inexact.');
      await _plugin.zonedSchedule(
        id,
        note.displayTitle,
        note.preview.isEmpty ? 'Reminder' : note.preview,
        scheduled,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: _matchComponents(note.recurrence),
        payload: note.id,
      );
    }
    return id;
  }

  DateTimeComponents? _matchComponents(ReminderRecurrence recurrence) {
    switch (recurrence) {
      case ReminderRecurrence.none:
        return null;
      case ReminderRecurrence.daily:
        return DateTimeComponents.time;
      case ReminderRecurrence.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
    }
  }

  tz.TZDateTime _nextInstance(Note note) {
    final DateTime at = note.reminderAt!;
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled =
        tz.TZDateTime(tz.local, at.year, at.month, at.day, at.hour, at.minute);
    if (!scheduled.isAfter(now)) {
      switch (note.recurrence) {
        case ReminderRecurrence.none:
          // Fire almost immediately for overdue one-time reminders.
          scheduled = now.add(const Duration(seconds: 5));
          break;
        case ReminderRecurrence.daily:
          while (!scheduled.isAfter(now)) {
            scheduled = scheduled.add(const Duration(days: 1));
          }
          break;
        case ReminderRecurrence.weekly:
          while (!scheduled.isAfter(now)) {
            scheduled = scheduled.add(const Duration(days: 7));
          }
          break;
      }
    }
    return scheduled;
  }

  Future<void> cancel(int? notificationId) async {
    if (notificationId == null) return;
    await init();
    await _plugin.cancel(notificationId);
  }

  Future<void> cancelForNote(Note note) => cancel(_notificationIdFor(note));

  /// Called on startup and after a reboot broadcast so reminders survive
  /// restarts (Spec §6).
  Future<void> rescheduleAll(List<Note> notes) async {
    await init();
    for (final Note note in notes) {
      if (note.hasReminder && !note.isTrashed) {
        final int? id = await schedule(note);
        note.notificationId = id;
      }
    }
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
