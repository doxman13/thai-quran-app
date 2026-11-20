import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/hifz_session_config.dart';
import '../../theme/app_theme.dart';
import '../../utils/hifz_mastery_utils.dart';

/// Conditional Home banner shown whenever a midway Hifz session exists.
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
    final subtitle = formatActiveSessionSubtitle(snapshot, isThai: isThai);
    final isNewVerses = snapshot.sessionType == HifzSessionType.newVerses;
    final header = isThai
        ? (isNewVerses ? 'ท่องจำอายะฮฺค้างอยู่' : 'ทบทวนฮิฟซ์ค้างอยู่')
        : (isNewVerses ? 'Paused Hifz Session' : 'Paused Hifz Review');

    return Semantics(
      container: true,
      label: '$header: $subtitle',
      child: Material(
        color: appColors.mushafGoldSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: onResume,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: appColors.mushafGoldBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: appColors.mushafGoldBorder),
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: appColors.mushafGold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        header,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: appColors.mushafGold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: appColors.textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: onResume,
                  style: FilledButton.styleFrom(
                    backgroundColor: appColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(64, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  child: Text(
                    isThai ? 'ท่องต่อ' : 'Resume',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
