import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Unboxed single-row 4-shortcut bar for core daily actions (Meaning, Mushaf, Hifz, Goals).
class HomeStudyHubGrid extends StatelessWidget {
  final bool isThai;
  final AppThemeColors appColors;
  final String? hifzSubtitleOverride;
  final VoidCallback onOpenMeaning;
  final VoidCallback onOpenMushaf;
  final VoidCallback onOpenHifz;
  final VoidCallback onOpenGoals;

  const HomeStudyHubGrid({
    super.key,
    required this.isThai,
    required this.appColors,
    this.hifzSubtitleOverride,
    required this.onOpenMeaning,
    required this.onOpenMushaf,
    required this.onOpenHifz,
    required this.onOpenGoals,
  });

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      _ShortcutItem(
        icon: Icons.menu_book_outlined,
        title: isThai ? 'ความหมาย' : 'Meaning',
        isGoldAccent: false,
        onTap: onOpenMeaning,
      ),
      _ShortcutItem(
        icon: Icons.auto_stories_outlined,
        title: isThai ? 'มุศหัฟ' : 'Mushaf',
        isGoldAccent: true,
        onTap: onOpenMushaf,
      ),
      _ShortcutItem(
        icon: Icons.lightbulb_outline_rounded,
        title: isThai ? 'ท่องจำ' : 'Hifz',
        isGoldAccent: false,
        hasBadgeDot: hifzSubtitleOverride != null,
        onTap: onOpenHifz,
      ),
      _ShortcutItem(
        icon: Icons.flag_outlined,
        title: isThai ? 'เป้าหมาย' : 'Goals',
        isGoldAccent: true,
        onTap: onOpenGoals,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final useTwoByTwo = constraints.maxWidth < 300 || textScale >= 1.55;
        if (useTwoByTwo) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _UnboxedShortcutTile(
                      item: shortcuts[0],
                      appColors: appColors,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _UnboxedShortcutTile(
                      item: shortcuts[1],
                      appColors: appColors,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _UnboxedShortcutTile(
                      item: shortcuts[2],
                      appColors: appColors,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _UnboxedShortcutTile(
                      item: shortcuts[3],
                      appColors: appColors,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: shortcuts
              .map(
                (item) => Expanded(
                  child: _UnboxedShortcutTile(
                    item: item,
                    appColors: appColors,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ShortcutItem {
  final IconData icon;
  final String title;
  final bool isGoldAccent;
  final bool hasBadgeDot;
  final VoidCallback onTap;

  const _ShortcutItem({
    required this.icon,
    required this.title,
    required this.isGoldAccent,
    this.hasBadgeDot = false,
    required this.onTap,
  });
}

class _UnboxedShortcutTile extends StatelessWidget {
  final _ShortcutItem item;
  final AppThemeColors appColors;

  const _UnboxedShortcutTile({
    required this.item,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.isGoldAccent ? appColors.mushafGold : appColors.primary;
    final iconBg =
        item.isGoldAccent ? appColors.mushafGoldSoft : appColors.primaryLight;

    return Semantics(
      button: true,
      label: item.title,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Icon(item.icon, size: 23, color: accent),
                  ),
                  if (item.hasBadgeDot)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: appColors.mushafGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: appColors.textStrong,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
