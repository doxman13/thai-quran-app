import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../data/quran_repository.dart';
import '../services/remote_content_service.dart';

class WelcomeScreen extends StatefulWidget {
  final QuranRepository repository;

  const WelcomeScreen({super.key, required this.repository});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_syncInBackground());
  }

  Future<void> _syncInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome', true);
    } catch (error) {
      debugPrint('Unable to persist welcome state: $error');
    }

    try {
      await RemoteContentService.instance.updateAllIfDue();
    } catch (error) {
      debugPrint('Unable to auto-check Quran content updates: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      repository: widget.repository,
      repositoryReady: false,
    );
  }
}
