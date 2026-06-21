// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/progress_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/local_reading_provider.dart';
import 'providers/supabase_provider.dart';
import 'data/quran_repository.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.prewarmFonts();

  await Supabase.initialize(
    url: 'https://qeciqdjidugdipgqxysm.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFlY2lxZGppZHVnZGlwZ3F4eXNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE5MzQxMzcsImV4cCI6MjA5NzUxMDEzN30.HtEVA3me06ShjtTRe6KdjV6qd3hPkiJTC9GAW0xDGuY',
  );

  final repository = QuranRepository();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SupabaseProvider()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LocalReadingProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
      ],
      child: ThaiQuranApp(repository: repository),
    ),
  );
}

class ThaiQuranApp extends StatelessWidget {
  final QuranRepository repository;
  const ThaiQuranApp({
    Key? key,
    required this.repository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final swatch = settings.getThemeSwatch();
        final lightColors = AppTheme.colors(
          isDark: false,
          palette: settings.themeColor,
        );
        final darkColors = AppTheme.colors(
          isDark: true,
          palette: settings.themeColor,
        );

        return MaterialApp(
          title: 'Thai Quran',
          debugShowCheckedModeBanner: false,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            primarySwatch: swatch,
            primaryColor: lightColors.primary,
            scaffoldBackgroundColor: lightColors.background,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: lightColors.primary,
              brightness: Brightness.light,
              surface: lightColors.surface,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: lightColors.surfaceMuted,
              foregroundColor: lightColors.textStrong,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: lightColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                side: BorderSide(color: lightColors.borderSoft),
              ),
            ),
          ),
          darkTheme: ThemeData(
            primarySwatch: swatch,
            primaryColor: darkColors.primary,
            scaffoldBackgroundColor: darkColors.background,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: darkColors.primary,
              brightness: Brightness.dark,
              surface: darkColors.surface,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: darkColors.surfaceMuted,
              foregroundColor: darkColors.textStrong,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: darkColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                side: BorderSide(color: darkColors.borderSoft),
              ),
            ),
          ),
          home: WelcomeScreen(repository: repository),
        );
      },
    );
  }
}
