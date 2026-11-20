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

/// Lightweight horizontal strip of Pinned Surahs with minimal visual framing.
class HomeQuickSurahs extends StatelessWidget {
  final List<HomeQuickSurahItem> items;
  final bool canPinMore;
  final bool isThai;
  final AppThemeColors appColors;
  final VoidCallback onPinTap;
  final ValueChanged<HomeQuickSurahItem> onItemTap;
  final ValueChanged<HomeQuickSurahItem>? onItemLongPress;

  const HomeQuickSurahs({
    super.key,
    required this.items,
    required this.canPinMore,
    required this.isThai,
    required this.appColors,
    required this.onPinTap,
    required this.onItemTap,
    this.onItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isFriday = DateTime.now().weekday == DateTime.friday;
    final scaler = MediaQuery.textScalerOf(context);
    final listHeight =
        (34 + scaler.scale(34) * 1.35).ceilToDouble().clamp(72.0, 128.0);

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
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: appColors.textStrong,
                ),
              ),
            ),
            if (canPinMore)
              TextButton.icon(
                onPressed: onPinTap,
                icon: Icon(Icons.add_rounded, size: 17, color: appColors.foreground),
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
                  minimumSize: const Size(44, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
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
              final customOrFridayTag = item.label.trim().isNotEmpty
                  ? item.label.trim()
                  : (isFridayKahf
                      ? (isThai ? 'ซุนนะฮฺวันศุกร์' : 'Friday Sunnah')
                      : null);

              return Semantics(
                button: true,
                label: customOrFridayTag != null
                    ? '$surahName ($customOrFridayTag)'
                    : surahName,
                child: Material(
                  color: appColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: InkWell(
                    onTap: () => onItemTap(item),
                    onLongPress: onItemLongPress != null && !item.isLocked
                        ? () => onItemLongPress!(item)
                        : null,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Container(
                      width: 138,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: isFridayKahf
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(AppTheme.radius),
                              border: Border.all(
                                color: appColors.mushafGoldBorder,
                              ),
                            )
                          : null,
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                              if (customOrFridayTag != null)
                                Text(
                                  customOrFridayTag,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: isFridayKahf
                                        ? appColors.mushafGold
                                        : appColors.textMuted,
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
            },
          ),
        ),
      ],
    );
  }
}
