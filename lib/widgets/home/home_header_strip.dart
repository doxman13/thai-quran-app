import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Compact single-line greeting + flame streak counter placed above the Home hero.
class HomeHeaderStrip extends StatelessWidget {
  final String displayName;
  final int streakCount;
  final bool hasReadToday;
  final bool isThai;
  final AppThemeColors appColors;

  const HomeHeaderStrip({
    super.key,
    required this.displayName,
    required this.streakCount,
    required this.hasReadToday,
    required this.isThai,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    final greetingText = displayName.trim().isNotEmpty
        ? (isThai ? 'ยินดีต้อนรับ, $displayName' : 'Welcome, $displayName')
        : (isThai ? 'ยินดีต้อนรับสู่การอ่านวันนี้' : 'Welcome back');

    final streakLabel = isThai ? '$streakCount วัน' : '${streakCount}d';
    final semanticStreak = isThai
        ? 'สถิติการอ่านต่อเนื่อง $streakCount วัน${hasReadToday ? ' อ่านแล้ววันนี้' : ' ยังไม่ได้อ่านวันนี้'}'
        : '$streakCount day reading streak${hasReadToday ? ', completed today' : ', not yet read today'}';

    final pillBg = hasReadToday ? appColors.primaryLight : appColors.surfaceMuted;
    final pillBorder =
        hasReadToday ? appColors.primaryLightBorder : appColors.borderSoft;
    final pillFg = hasReadToday ? appColors.primary : appColors.textMuted;

    return Row(
      children: [
        Expanded(
          child: Text(
            greetingText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansThai(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appColors.foreground,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: semanticStreak,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: pillBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasReadToday
                      ? Icons.local_fire_department_rounded
                      : Icons.local_fire_department_outlined,
                  size: 16,
                  color: pillFg,
                ),
                const SizedBox(width: 4),
                Text(
                  streakLabel,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: pillFg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
