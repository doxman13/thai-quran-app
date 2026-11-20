import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

class HomeGoalSnapshotItem {
  final String modeLabel;
  final bool isMushaf;
  final String title;
  final String subtitle;
  final double progress;
  final VoidCallback onTap;

  const HomeGoalSnapshotItem({
    required this.modeLabel,
    required this.isMushaf,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.onTap,
  });
}

/// Calm "Your Progress"-style Reading Goals grouping with pastel circle icons & single clean container.
class HomeGoalsSnapshot extends StatelessWidget {
  final List<HomeGoalSnapshotItem> items;
  final int totalActiveCount;
  final bool isThai;
  final AppThemeColors appColors;
  final VoidCallback onManageTap;

  const HomeGoalsSnapshot({
    super.key,
    required this.items,
    required this.totalActiveCount,
    required this.isThai,
    required this.appColors,
    required this.onManageTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(2).toList();
    final extraCount = totalActiveCount - visibleItems.length;
    final viewAllLabel = extraCount > 0
        ? (isThai ? 'ทั้งหมด +$extraCount' : 'View all +$extraCount')
        : (totalActiveCount == 0
            ? (isThai ? 'ตั้งเป้าหมาย' : 'Create')
            : (isThai ? 'ทั้งหมด' : 'View all'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isThai ? 'เป้าหมายการอ่าน' : 'Your Goals',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansThai(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: appColors.textStrong,
                ),
              ),
            ),
            IconButton(
              onPressed: onManageTap,
              icon: Icon(Icons.add_rounded, size: 19, color: appColors.textMuted),
              tooltip: isThai ? 'เพิ่มหรือจัดการเป้าหมาย' : 'Add or manage goals',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
            ),
            TextButton(
              onPressed: onManageTap,
              style: TextButton.styleFrom(
                foregroundColor: appColors.foreground,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: const Size(44, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    viewAllLabel,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: appColors.foreground,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: appColors.textMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (totalActiveCount == 0)
          Material(
            color: appColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: InkWell(
              onTap: onManageTap,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: appColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.flag_outlined,
                        color: appColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isThai
                                ? 'ตั้งเป้าหมายการอ่านอัลกุรอาน'
                                : 'Set a Reading Goal',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: appColors.textStrong,
                            ),
                          ),
                          Text(
                            isThai
                                ? 'เลือกแผนอ่านจบ 30 วัน หรือกำหนดเป้าหมายเอง'
                                : 'Pick a 30-day Khatam plan or custom target',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              color: appColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: appColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Material(
            color: appColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: Column(
              children: [
                for (int i = 0; i < visibleItems.length; i++) ...[
                  _CalmGoalRow(
                    item: visibleItems[i],
                    appColors: appColors,
                  ),
                  if (i < visibleItems.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: appColors.borderSoft.withValues(alpha: 0.65),
                      ),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CalmGoalRow extends StatelessWidget {
  final HomeGoalSnapshotItem item;
  final AppThemeColors appColors;

  const _CalmGoalRow({
    required this.item,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.isMushaf ? appColors.mushafGold : appColors.primary;
    final badgeBg =
        item.isMushaf ? appColors.mushafGoldSoft : appColors.primaryLight;
    final pct = (item.progress * 100).round().clamp(0, 100);

    return Semantics(
      button: true,
      label: '${item.title}, ${item.modeLabel}, ${item.subtitle}, $pct%',
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.isMushaf
                      ? Icons.import_contacts_rounded
                      : Icons.menu_book_rounded,
                  size: 17,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: appColors.textStrong,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pct%',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.modeLabel} · ${item.subtitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11.5,
                        color: appColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: 3,
                        backgroundColor: appColors.borderSoft.withValues(alpha: 0.7),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: appColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
