import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Editorial section header ("Today" / "วันนี้ของคุณ") paired with a subtle streak pill.
class HomeHeaderStrip extends StatelessWidget {
  final String displayName;
  final int streakCount;
  final bool hasReadToday;
  final bool isThai;
  final AppThemeColors appColors;

  const HomeHeaderStrip({
    super.key,
    this.displayName = '',
    required this.streakCount,
    required this.hasReadToday,
    required this.isThai,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    final todayLabel = isThai ? 'วันนี้ของคุณ' : 'Today';
    final streakLabel = isThai ? '$streakCount วันต่อเนื่อง' : '${streakCount}d streak';
    final semanticStreak = isThai
        ? 'สถิติการอ่านต่อเนื่อง $streakCount วัน${hasReadToday ? ' อ่านแล้ววันนี้' : ' ยังไม่ได้อ่านวันนี้'}'
        : '$streakCount day reading streak${hasReadToday ? ', completed today' : ', not yet read today'}';

    final pillBg = hasReadToday ? appColors.primaryLight : appColors.mushafGoldSoft;
    final pillBorder = hasReadToday
        ? appColors.primaryLightBorder.withValues(alpha: 0.7)
        : appColors.mushafGoldBorder.withValues(alpha: 0.6);
    final pillFg = hasReadToday ? appColors.primary : appColors.mushafGold;

    return Row(
      children: [
        Expanded(
          child: Text(
            todayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansThai(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: appColors.textStrong,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: semanticStreak,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
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
                      : Icons.auto_awesome_outlined,
                  size: 15,
                  color: pillFg,
                ),
                const SizedBox(width: 5),
                Text(
                  streakLabel,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
