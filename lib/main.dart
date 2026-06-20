// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/progress_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/local_reading_provider.dart';
import 'providers/supabase_provider.dart';
import 'data/quran_repository.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qeciqdjidugdipgqxysm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFlY2lxZGppZHVnZGlwZ3F4eXNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE5MzQxMzcsImV4cCI6MjA5NzUxMDEzN30.HtEVA3me06ShjtTRe6KdjV6qd3hPkiJTC9GAW0xDGuY',
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
  const ThaiQuranApp({Key? key, required this.repository}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final swatch = settings.getThemeSwatch();
        final primaryColor = settings.getPrimaryColor();
        final isSepia = settings.themeColor == 'sepia';

        Color scaffoldBg;
        if (settings.isDarkMode) {
          if (isSepia) {
            scaffoldBg = const Color(0xFF1E1712);
          } else if (settings.themeColor == 'grey') {
            scaffoldBg = const Color(0xFF2D3748); // Soft grey
          } else {
            scaffoldBg = const Color(0xFF0F172A);
          }
        } else {
          scaffoldBg = isSepia
              ? const Color(0xFFFBF0D9)
              : const Color(0xFFF8FAFC);
        }

        return MaterialApp(
          title: 'Thai Quran',
          debugShowCheckedModeBanner: false,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            primarySwatch: swatch,
            primaryColor: primaryColor,
            scaffoldBackgroundColor: scaffoldBg,
            brightness: Brightness.light,
            appBarTheme: AppBarTheme(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          darkTheme: ThemeData(
            primarySwatch: swatch,
            primaryColor: primaryColor,
            scaffoldBackgroundColor: scaffoldBg,
            brightness: Brightness.dark,
            appBarTheme: AppBarTheme(
              backgroundColor: settings.isDarkMode
                  ? (isSepia
                        ? const Color(0xFF2E241D)
                        : (settings.themeColor == 'emerald'
                              ? const Color(0xFF022C22)
                              : (settings.themeColor == 'grey'
                                    ? const Color(0xFF1A202C)
                                    : primaryColor)))
                  : primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          home: HomeScreen(repository: repository),
        );
      },
    );
  }
}
