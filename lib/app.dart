import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/label_repository.dart';
import 'data/repositories/note_repository.dart';
import 'data/services/notification_service.dart';
import 'data/services/settings_service.dart';
import 'providers/labels_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/archive_screen.dart';
import 'screens/about_screen.dart';
import 'screens/ai_settings_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/checklist_editor_screen.dart';
import 'screens/drawing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/image_note_screen.dart';
import 'screens/labels_screen.dart';
import 'screens/note_editor_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/trash_screen.dart';
import 'screens/voice_note_screen.dart';

/// Root navigator key — lets notification taps open the right note (Spec §6).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class NoteNestApp extends StatefulWidget {
  const NoteNestApp({super.key});

  @override
  State<NoteNestApp> createState() => _NoteNestAppState();
}

class _NoteNestAppState extends State<NoteNestApp> {
  @override
  void initState() {
    super.initState();
    // Tapping a reminder notification opens that note.
    NotificationService.instance.onSelectNote = (String noteId) {
      appNavigatorKey.currentState?.pushNamed('/note', arguments: noteId);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(SettingsService.instance)..load(),
        ),
        ChangeNotifierProvider<LabelsProvider>(
          create: (_) => LabelsProvider(LabelRepository(), NoteRepository())..load(),
        ),
        ChangeNotifierProvider<NotesProvider>(
          create: (_) => NotesProvider(NoteRepository())..init(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (BuildContext context, SettingsProvider settings, _) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'NoteNest',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.light(settings.themePack),
            darkTheme: AppTheme.dark(settings.themePack),
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashScreen(),
            routes: <String, WidgetBuilder>{
              '/home': (_) => const HomeScreen(),
              '/onboarding': (_) => const OnboardingScreen(),
              '/search': (_) => const SearchScreen(),
              '/labels': (_) => const LabelsScreen(),
              '/reminders': (_) => const RemindersScreen(),
              '/archive': (_) => const ArchiveScreen(),
              '/trash': (_) => const TrashScreen(),
              '/settings': (_) => const SettingsScreen(),
              '/backup': (_) => const BackupScreen(),
              '/about': (_) => const AboutScreen(),
              '/signin': (_) => const SignInScreen(),
              '/ai': (_) => const AiSettingsScreen(),
            },
            onGenerateRoute: (RouteSettings routeSettings) {
              final Object? args = routeSettings.arguments;
              switch (routeSettings.name) {
                case '/note':
                  return MaterialPageRoute<void>(
                    builder: (_) => NoteEditorScreen(noteId: args as String),
                    settings: routeSettings,
                  );
                case '/checklist':
                  return MaterialPageRoute<void>(
                    builder: (_) => ChecklistEditorScreen(noteId: args as String),
                    settings: routeSettings,
                  );
                case '/drawing':
                  return MaterialPageRoute<void>(
                    builder: (_) => DrawingScreen(noteId: args as String),
                    settings: routeSettings,
                  );
                case '/voice':
                  return MaterialPageRoute<void>(
                    builder: (_) => VoiceNoteScreen(noteId: args as String),
                    settings: routeSettings,
                  );
                case '/image':
                  return MaterialPageRoute<void>(
                    builder: (_) => ImageNoteScreen(noteId: args as String),
                    settings: routeSettings,
                  );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
