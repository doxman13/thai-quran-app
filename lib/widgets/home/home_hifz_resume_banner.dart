import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/offline_surah_names.dart';
import '../../models/hifz_session_config.dart';
import '../../theme/app_theme.dart';
import '../../utils/hifz_mastery_utils.dart';

/// Quiet warm-sand banner shown whenever a midway Hifz session exists.
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
          ? (isThai
              ? 'ขั้น $stepNum/${snapshot.totalSteps}'
              : 'Step $stepNum/${snapshot.totalSteps}')
          : (isThai ? 'ขั้น $stepNum' : 'Step $stepNum');
      final tallyPart = isThai
          ? 'รอบ ${snapshot.currentTally}/${snapshot.targetTally}'
          : '${snapshot.currentTally}/${snapshot.targetTally}';
      final versePart = snapshot.currentVerse != null
          ? (isThai
              ? 'อายะฮฺที่ ${snapshot.currentVerse}'
              : 'Ayah ${snapshot.currentVerse}')
          : null;
      subtitle = [
        '$surah:$start–$end',
        ?versePart,
        stepPart,
        tallyPart,
      ].join(' · ');
    } else {
      header = isThai ? 'ทบทวนต่อ · ฮิฟซ์' : 'Resume Hifz Review';
      subtitle = formatActiveSessionSubtitle(snapshot, isThai: isThai);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stripBg = isDark ? appColors.surfaceMuted : appColors.mushafGoldSoft;

    return Semantics(
      container: true,
      button: true,
      label: '$header: $subtitle',
      child: Material(
        color: stripBg,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: onResume,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: appColors.textStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          color: appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onResume,
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: appColors.textStrong,
                  ),
                  tooltip: isThai ? 'ท่องต่อ' : 'Resume',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: onDiscard,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: appColors.textMuted,
                  ),
                  tooltip: isThai ? 'ยกเลิกเซสชันนี้' : 'Discard session',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
