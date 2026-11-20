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

/// Option 1 Pinned Surahs horizontal strip with single-tap cards (no 4-target crowding).
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
        (36 + scaler.scale(42) * 1.4).ceilToDouble().clamp(88.0, 148.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.push_pin_outlined, size: 17, color: appColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isThai ? 'ซูเราะฮฺที่ปักหมุด' : 'Pinned Surahs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansThai(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: appColors.textStrong,
                ),
              ),
            ),
            if (canPinMore)
              TextButton.icon(
                onPressed: onPinTap,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  isThai ? 'ปักหมุด' : 'Pin',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: appColors.primary,
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
              final subLabel = item.label.trim().isNotEmpty
                  ? item.label.trim()
                  : (isFriday && item.surahNumber == 18
                      ? (isThai ? 'แนะนำวันศุกร์' : 'Friday Sunnah')
                      : (isThai ? 'แตะเพื่อเปิดอ่าน' : 'Tap to read'));
              final isFridayKahf = isFriday && item.surahNumber == 18;

              return Semantics(
                button: true,
                label: '$surahName ($subLabel)',
                child: Material(
                  color: appColors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: InkWell(
                    onTap: () => onItemTap(item),
                    onLongPress: onItemLongPress != null && !item.isLocked
                        ? () => onItemLongPress!(item)
                        : null,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Container(
                      width: 152,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(
                          color: isFridayKahf
                              ? appColors.mushafGoldBorder
                              : appColors.borderSoft,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: appColors.primaryLight,
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusSm),
                                ),
                                child: Text(
                                  sId,
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: appColors.primary,
                                  ),
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
                                      fontSize: 15,
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
                                  fontWeight: FontWeight.w700,
                                  color: appColors.textStrong,
                                ),
                              ),
                              Text(
                                subLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 11,
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
