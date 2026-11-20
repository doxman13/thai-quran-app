import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Calm editorial 2x2 mode grid aligned with Anti-AI Manuscript tokens.
class HomeStudyHubGrid extends StatelessWidget {
  final bool isThai;
  final AppThemeColors appColors;
  final String? hifzSubtitleOverride;
  final VoidCallback onOpenMeaning;
  final VoidCallback onOpenMushaf;
  final VoidCallback onOpenHifz;
  final VoidCallback onOpenTopics;

  const HomeStudyHubGrid({
    super.key,
    required this.isThai,
    required this.appColors,
    this.hifzSubtitleOverride,
    required this.onOpenMeaning,
    required this.onOpenMushaf,
    required this.onOpenHifz,
    required this.onOpenTopics,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.grid_view_rounded, size: 17, color: appColors.primary),
            const SizedBox(width: 8),
            Text(
              isThai ? 'โหมดการศึกษา' : 'Study Hubs',
              style: GoogleFonts.notoSansThai(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: appColors.textStrong,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _EditorialModeCard(
                  icon: Icons.menu_book_rounded,
                  title: isThai ? 'อ่านฉบับแปล' : 'Meaning Reader',
                  subtitle: isThai
                      ? 'แปลไทย คำต่อคำ & ตัฟซีร'
                      : 'Thai, Word-by-Word & Tafsir',
                  isGoldAccent: false,
                  appColors: appColors,
                  onTap: onOpenMeaning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EditorialModeCard(
                  icon: Icons.auto_stories_rounded,
                  title: isThai ? 'มุศหัฟมะดีนะฮฺ' : 'Medina Mushaf',
                  subtitle: isThai
                      ? 'หน้า 1–604 · 15 บรรทัด'
                      : 'Pages 1–604 · 15-Line',
                  isGoldAccent: true,
                  appColors: appColors,
                  onTap: onOpenMushaf,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _EditorialModeCard(
                  icon: Icons.psychology_rounded,
                  title: isThai ? 'ท่องจำอัลกุรอาน' : 'Hifz Memorize',
                  subtitle: hifzSubtitleOverride ??
                      (isThai ? 'ฝึกตักร็อร & ทบทวน' : 'Takrar & Review'),
                  isGoldAccent: false,
                  appColors: appColors,
                  onTap: onOpenHifz,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EditorialModeCard(
                  icon: Icons.category_outlined,
                  title: isThai ? 'หัวข้ออัลกุรอาน' : 'Quran Topics',
                  subtitle: isThai
                      ? 'สำรวจอายะฮฺตามหมวดหมู่'
                      : 'Browse Verses by Topic',
                  isGoldAccent: true,
                  appColors: appColors,
                  onTap: onOpenTopics,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorialModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGoldAccent;
  final AppThemeColors appColors;
  final VoidCallback onTap;

  const _EditorialModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGoldAccent,
    required this.appColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isGoldAccent ? appColors.mushafGold : appColors.primary;
    final iconBg =
        isGoldAccent ? appColors.mushafGoldSoft : appColors.primaryLight;

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: appColors.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(icon, size: 18, color: accent),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: appColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: appColors.textStrong,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: appColors.textMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
