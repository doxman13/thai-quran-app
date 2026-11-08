import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../widgets/topics_tab_view.dart';

class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isThai = settings.languageCode == 'th';
    final colors = settings.getAppColors();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          isThai ? 'หัวข้ออัลกุรอาน' : 'Quran Topics',
          style: GoogleFonts.notoSansThai(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textStrong,
          ),
        ),
        elevation: 0,
        backgroundColor: colors.background,
        iconTheme: IconThemeData(color: colors.textStrong),
      ),
      body: const SafeArea(
        child: TopicsTabView(),
      ),
    );
  }
}
