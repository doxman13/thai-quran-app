import 'package:flutter/material.dart';

import '../data/quran_repository.dart';
import 'settings_screen.dart';

/// Unified Profile Screen delegating to the minimal Reveal-style [SettingsScreen].
class ProfileScreen extends StatelessWidget {
  final QuranRepository? repository;
  final bool isEmbedded;
  final VoidCallback? onOpenGoalsTab;

  const ProfileScreen({
    super.key,
    this.repository,
    this.isEmbedded = false,
    this.onOpenGoalsTab,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(
      repository: repository,
      initialCategory: SettingsCategoryTab.profile,
    );
  }
}
