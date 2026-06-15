// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/progress_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/bookmark_provider.dart';
import 'data/quran_repository.dart';
import 'screens/home_screen.dart';

void main() {
  final repository = QuranRepository();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
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
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            primarySwatch: Colors.teal,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.teal,
            scaffoldBackgroundColor: const Color(0xFF0F172A), // Deep Slate Dark Mode
            brightness: Brightness.dark,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF022C22), // Very dark teal
            ),
          ),
          home: HomeScreen(repository: repository),
        );
      },
    );
  }
}
