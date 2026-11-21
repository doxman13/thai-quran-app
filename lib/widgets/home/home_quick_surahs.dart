import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/offline_surah_names.dart';
import '../../theme/app_theme.dart';

class HomeQuickSurahItem {
  final String id;
  final int surahNumber;
  final String label;
  final bool isLocked;

  const HomeQuickSurahItem({
    required this.id,
    required this.surahNumber,
    required this.label,
    required this.isLocked,
  });
}

/// Compact horizontal strip of Pinned Surahs displaying only number, Arabic name, and Thai/English name.
class HomeQuickSurahs extends StatelessWidget {
  final List<HomeQuickSurahItem> items;
  final bool canPinMore;
  final bool isThai;
  final AppThemeColors appColors;
  final VoidCallback onPinTap;
  final VoidCallback? onManageTap;
  final ValueChanged<HomeQuickSurahItem> onItemTap;
  final ValueChanged<HomeQuickSurahItem>? onItemLongPress;

  const HomeQuickSurahs({
    super.key,
    required this.items,
    required this.canPinMore,
    required this.isThai,
    required this.appColors,
    required this.onPinTap,
    this.onManageTap,
    required this.onItemTap,
    this.onItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isFriday = DateTime.now().weekday == DateTime.friday;
    final scaler = MediaQuery.textScalerOf(context);
    final listHeight =
        (26 + scaler.scale(26) * 1.2).ceilToDouble().clamp(60.0, 96.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isThai ? 'ซูเราะฮฺที่ปักหมุด' : 'Pinned Surahs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansThai(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appColors.textStrong,
                ),
              ),
            ),
            if (onManageTap != null)
              TextButton(
                onPressed: onManageTap,
                style: TextButton.styleFrom(
                  foregroundColor: appColors.textMuted,
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  minimumSize: const Size(44, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  isThai ? 'จัดการ' : 'Manage',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: appColors.textMuted,
                  ),
                ),
              ),
            if (canPinMore)
              TextButton.icon(
                onPressed: onPinTap,
                icon: Icon(
                  Icons.add_rounded,
                  size: 17,
                  color: appColors.foreground,
                ),
                label: Text(
                  isThai ? 'ปักหมุด' : 'Pin',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: appColors.foreground,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  minimumSize: const Size(44, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final sId = item.surahNumber.toString();
              final surahName = surahDisplayName(sId, isThai: isThai);
              final arName = offlineSurahNamesAr[sId] ?? '';
              final isFridayKahf = isFriday && item.surahNumber == 18;

              return Semantics(
                button: true,
                label: '$sId $surahName',
                child: Material(
                  color: appColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    side: BorderSide(
                      color: isFridayKahf
                          ? appColors.mushafGoldBorder
                          : appColors.borderSoft.withValues(alpha: 0.7),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => onItemTap(item),
                    onLongPress: onItemLongPress != null && !item.isLocked
                        ? () => onItemLongPress!(item)
                        : null,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: SizedBox(
                      width: 128,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  sId,
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: appColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (arName.isNotEmpty)
                                  Expanded(
                                    child: Text(
                                      arName,
                                      textAlign: TextAlign.end,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'UthmanicHafs',
                                        fontSize: 14.5,
                                        color: appColors.mushafGold,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              surahName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: appColors.textStrong,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
