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

/// Concise Reading Goals preview (max 2 visible rows + overflow count CTA).
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
    final manageText = extraCount > 0
        ? (isThai ? '+$extraCount ทั้งหมด' : '+$extraCount more')
        : (isThai ? 'จัดการเป้าหมาย' : 'Manage');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag_rounded, size: 17, color: appColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isThai ? 'เป้าหมายการอ่าน' : 'Reading Goals',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansThai(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: appColors.textStrong,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onManageTap,
              icon: Text(
                manageText,
                style: GoogleFonts.notoSansThai(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: appColors.primary,
                ),
              ),
              label: Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: appColors.primary,
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                minimumSize: const Size(44, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: appColors.borderSoft),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: appColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        Icons.flag_outlined,
                        color: appColors.primary,
                        size: 20,
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
                            style: GoogleFonts.notoSansThai(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: appColors.textStrong,
                            ),
                          ),
                          Text(
                            isThai
                                ? 'เลือกแผนอ่านจบ 30 วัน หรือกำหนดเป้าหมายเอง'
                                : 'Pick a 30-day Khatam plan or custom target',
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
          ...visibleItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GoalSnapshotCard(
                item: item,
                appColors: appColors,
              ),
            ),
          ),
      ],
    );
  }
}

class _GoalSnapshotCard extends StatelessWidget {
  final HomeGoalSnapshotItem item;
  final AppThemeColors appColors;

  const _GoalSnapshotCard({
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
      label: '${item.title}, ${item.subtitle}, $pct%',
      child: Material(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: appColors.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        item.modeLabel,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: appColors.textStrong,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pct%',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.play_circle_fill_rounded,
                      size: 20,
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    color: appColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 5,
                    backgroundColor: appColors.borderSoft,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
