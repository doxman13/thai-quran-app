// lib/widgets/surah_mastery_card.dart
//
// Shared Surah mastery/progress card used by the Hifz landing grid and the
// standalone Hifz Mastery list. A Surah counts as "mastered" once all of its
// verses are memorized and it has been reviewed at least three times.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/hifz_session_config.dart';

class SurahMasteryCard extends StatelessWidget {
  /// Number of reviews required before a completed Surah is considered
  /// "mastered".
  static const int masteredReviewThreshold = 3;

  final int surahNumber;
  final String surahName;
  final int verseCount;
  final int juz;
  final SurahCompletionRecord? record;
  final bool isThai;
  final VoidCallback? onTap;

  const SurahMasteryCard({
    super.key,
    required this.surahNumber,
    required this.surahName,
    required this.verseCount,
    required this.juz,
    required this.record,
    required this.isThai,
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
    final isMastered = isMasteredRecord(record);
    final isInProgress = isInProgressRecord(record);
    final reviewCount = record?.reviewCount ?? 0;

    final statusColor = isMastered
        ? const Color(0xFF15803D)
        : (isInProgress
            ? const Color(0xFFB45309)
            : colorScheme.onSurfaceVariant);
    final statusLabel = isMastered
        ? (isThai ? 'จำขึ้นใจแล้ว' : 'Mastered')
        : (isInProgress
            ? (isThai ? 'กำลังท่อง' : 'In Progress')
            : (isThai ? 'เริ่มท่อง' : 'Start'));

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMastered
                  ? const Color(0xFF15803D).withValues(alpha: 0.4)
                  : (isInProgress
                      ? const Color(0xFFD97706).withValues(alpha: 0.4)
                      : colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$surahNumber',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surahName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '$verseCount ${isThai ? 'อายะฮฺ' : 'verses'} • ${isThai ? 'ญุซอ์' : 'Juz'} $juz${reviewCount > 0 ? ' • ${isThai ? 'ทบทวน $reviewCount รอบ' : 'Reviewed ×$reviewCount'}' : ''}',
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
                  borderRadius: BorderRadius.circular(12),
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
