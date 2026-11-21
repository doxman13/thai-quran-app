import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/offline_surah_names.dart';
import '../../models/hifz_session_config.dart';
import '../../theme/app_theme.dart';
import '../../utils/hifz_mastery_utils.dart';

/// Lightweight inline task reminder shown whenever a midway Hifz session exists.
class HomeHifzResumeBanner extends StatelessWidget {
  final ActiveSessionSnapshot snapshot;
  final bool isThai;
  final AppThemeColors appColors;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const HomeHifzResumeBanner({
    super.key,
    required this.snapshot,
    required this.isThai,
    required this.appColors,
    required this.onResume,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final isNewVerses = snapshot.sessionType == HifzSessionType.newVerses;
    final String header;
    final String subtitle;

    if (isNewVerses) {
      final surah = snapshot.nvSurahNumber ?? 1;
      final start = snapshot.nvStartVerse ?? 1;
      final end = snapshot.nvEndVerse ?? 1;
      final surahName = surahDisplayName(surah.toString(), isThai: isThai);
      header = isThai ? 'ท่องจำต่อ · $surahName' : 'Resume Hifz · $surahName';

      final stepNum = snapshot.totalSteps != null && snapshot.totalSteps! > 0
          ? (snapshot.currentStepIndex + 1).clamp(1, snapshot.totalSteps!)
          : snapshot.currentStepIndex + 1;
      final stepPart = snapshot.totalSteps != null && snapshot.totalSteps! > 0
          ? '$stepNum/${snapshot.totalSteps}'
          : (isThai ? 'ขั้น $stepNum' : 'Step $stepNum');
      final versePart = snapshot.currentVerse != null
          ? (isThai
              ? 'อายะฮฺที่ ${snapshot.currentVerse}'
              : 'Ayah ${snapshot.currentVerse}')
          : null;
      subtitle = ['$surah:$start–$end', ?versePart, stepPart].join(' · ');
    } else {
      header = isThai ? 'ทบทวนต่อ · ฮิฟซ์' : 'Resume Hifz Review';
      subtitle = formatActiveSessionSubtitle(snapshot, isThai: isThai);
    }

    return Semantics(
      container: true,
      button: true,
      label: '$header: $subtitle',
      child: Material(
        color: appColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(
            color: appColors.borderSoft.withValues(alpha: 0.75),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onResume,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: appColors.mushafGold, width: 3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          header,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: appColors.textStrong,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 11.5,
                            color: appColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: onResume,
                    icon: Text(
                      isThai ? 'ต่อ' : 'Continue',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(44, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  IconButton(
                    onPressed: onDiscard,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: appColors.textMuted,
                    ),
                    tooltip: isThai ? 'ยกเลิกเซสชันนี้' : 'Discard session',
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
