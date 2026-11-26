// lib/widgets/surah_mastery_card.dart
//
// Shared Surah mastery/progress card used by the Hifz landing grid and the
// standalone Hifz Mastery list. A Surah counts as "mastered" once all of its
// verses are memorized and it has been reviewed at least three times.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/offline_surah_names.dart';
import '../models/hifz_session_config.dart';
import '../theme/app_theme.dart';
import '../utils/hifz_mastery_utils.dart';

class SurahMasteryCard extends StatelessWidget {
  /// Number of reviews required before a completed Surah is considered
  /// "mastered".
  static const int masteredReviewThreshold = 3;

  final int surahNumber;
  final String surahName;
  final int verseCount;
  final int juz;
  final SurahCompletionRecord? record;
  final SurahMasterySummary? summary;
  final bool isThai;
  final bool groupedRow;
  final BorderRadius? groupedBorderRadius;
  final VoidCallback? onTap;

  const SurahMasteryCard({
    super.key,
    required this.surahNumber,
    required this.surahName,
    required this.verseCount,
    required this.juz,
    required this.record,
    this.summary,
    required this.isThai,
    this.groupedRow = false,
    this.groupedBorderRadius,
    this.onTap,
  });

  static bool isMasteredRecord(SurahCompletionRecord? record) =>
      record?.newVersesCompleted == true &&
      (record?.reviewCount ?? 0) >= masteredReviewThreshold;

  static bool isInProgressRecord(SurahCompletionRecord? record) =>
      !isMasteredRecord(record) &&
      (record?.newVersesCompleted == true || (record?.reviewCount ?? 0) > 0);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.appColors;
    final isMastered = summary != null
        ? summary!.status == HifzMasteryStatus.mastered
        : isMasteredRecord(record);
    final isInProgress = summary != null
        ? summary!.status == HifzMasteryStatus.inProgress
        : isInProgressRecord(record);
    final reviewCount = summary?.reviewCount ?? record?.reviewCount ?? 0;
    final nameAr = offlineSurahNamesAr['$surahNumber'] ?? '';

    String progressDetail = '';
    final active = summary?.hasActiveSession == true ? summary?.activeSession : null;
    if (active != null) {
      if (active.sessionType == HifzSessionType.newVerses &&
          active.currentVerse != null) {
        progressDetail = isThai
            ? ' • ค้างอายะฮฺ ${active.currentVerse} (${active.currentTally}/${active.targetTally})'
            : ' • Paused A.${active.currentVerse} (${active.currentTally}/${active.targetTally})';
      } else {
        progressDetail = isThai
            ? ' • ค้างอยู่ (${active.currentTally}/${active.targetTally})'
            : ' • Paused (${active.currentTally}/${active.targetTally})';
      }
    } else if (summary != null &&
        !summary!.newVersesCompleted &&
        summary!.furthestCompletedVerse > 0 &&
        summary!.furthestCompletedVerse < verseCount) {
      progressDetail = isThai
          ? ' • ถึงอายะฮฺ ${summary!.furthestCompletedVerse}/$verseCount'
          : ' • Up to A.${summary!.furthestCompletedVerse}/$verseCount';
    }

    final statusColor = isMastered
        ? colors.success
        : (isInProgress ? colors.mushafGold : colorScheme.onSurfaceVariant);
    final statusLabel = isMastered
        ? (isThai ? 'จำขึ้นใจแล้ว' : 'Mastered')
        : (isInProgress
            ? (isThai ? 'กำลังท่อง' : 'In Progress')
            : (isThai ? 'เริ่มท่อง' : 'Start'));

    final radius = groupedRow
        ? (groupedBorderRadius ?? BorderRadius.zero)
        : BorderRadius.circular(AppTheme.radius);

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: groupedRow
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(
                    color: isMastered
                        ? colors.success.withValues(alpha: 0.4)
                        : (isInProgress
                            ? colors.mushafGold.withValues(alpha: 0.45)
                            : colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isMastered
                      ? colors.success.withValues(alpha: 0.14)
                      : (isInProgress
                          ? colors.mushafGold.withValues(alpha: 0.14)
                          : colors.primary.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$surahNumber',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isMastered
                        ? colors.success
                        : (isInProgress ? colors.mushafGold : colors.primary),
                  ),
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
                            surahName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (nameAr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              nameAr,
                              style: TextStyle(
                                fontFamily: 'UthmanicHafs',
                                fontSize: 20,
                                height: 1.1,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$verseCount ${isThai ? 'อายะฮฺ' : 'verses'} • ${isThai ? 'ญุซอ์' : 'Juz'} $juz$progressDetail${reviewCount > 0 ? ' • ${isThai ? 'ทบทวน $reviewCount รอบ' : 'Reviewed ×$reviewCount'}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
