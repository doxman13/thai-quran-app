// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/progress_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/local_reading_provider.dart';
import 'providers/mushaf_reading_provider.dart';
import 'providers/supabase_provider.dart';
import 'providers/thai_text_protection_provider.dart';
import 'providers/translation_manager_provider.dart';
import 'data/quran_repository.dart';
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
        ChangeNotifierProvider(create: (_) => TranslationManagerProvider()),
        ChangeNotifierProvider(create: (_) => LocalReadingProvider()),
        ChangeNotifierProvider(create: (_) => MushafReadingProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
        ChangeNotifierProvider(create: (_) => ThaiTextProtectionProvider()),
      ],
      child: ThaiQuranApp(repository: repository),
    ),
  );
}

class ThaiQuranApp extends StatelessWidget {
  final QuranRepository repository;
  const ThaiQuranApp({Key? key, required this.repository}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'Thai Quran',
          debugShowCheckedModeBanner: false,
          
          // Connects your live app settings state directly into the theme engine
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          
          // Natively builds your beautiful Material 3 styles using your custom palette options
          theme: AppTheme.toThemeData(
            isDark: false, 
            palette: settings.themeColor,
          ),
          darkTheme: AppTheme.toThemeData(
            isDark: true, 
            palette: settings.themeColor,
          ),
          
          home: WelcomeScreen(repository: repository),
        );
      },
    );
  }
}