import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Calm, single-banner "Continue Reading" hero card inspired by quiet editorial journals.
class HomeContinueHero extends StatelessWidget {
  final bool hasHistory;
  final bool isMushaf;
  final String modeBadge;
  final String contextTag;
  final String mainTitle;
  final String subDetail;
  final String arabicSurahName;
  final String surahNameLabel;
  final double? progressFraction;
  final bool isSignedIn;
  final bool isThai;
  final VoidCallback onContinue;
  final VoidCallback onStartMeaning;
  final VoidCallback onStartMushaf;
  final VoidCallback? onSwitchMode;
  final VoidCallback? onSignInTap;

  const HomeContinueHero({
    super.key,
    required this.hasHistory,
    required this.isMushaf,
    required this.modeBadge,
    this.contextTag = '',
    required this.mainTitle,
    required this.subDetail,
    this.arabicSurahName = '',
    this.surahNameLabel = '',
    this.progressFraction,
    required this.isSignedIn,
    required this.isThai,
    required this.onContinue,
    required this.onStartMeaning,
    required this.onStartMushaf,
    this.onSwitchMode,
    this.onSignInTap,
  });

  static const Color _heroBgLight = Color(0xFF1A584A);
  static const Color _heroBgDark = Color(0xFF153028);
  static const Color _heroIvory = Color(0xFFFAF6EE);
  static const Color _heroGold = Color(0xFFD4A853);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _heroBgDark : _heroBgLight;

    return Semantics(
      container: true,
      button: true,
      label: '$modeBadge: $mainTitle',
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: hasHistory ? onContinue : onStartMeaning,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasHistory)
                  _buildFirstTimeContent()
                else
                  _buildResumeContent(),
                if (!isSignedIn && onSignInTap != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: onSignInTap,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_sync_outlined,
                            size: 15,
                            color: _heroGold,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isThai
                                  ? 'เข้าสู่ระบบเพื่อซิงก์การอ่านข้ามอุปกรณ์'
                                  : 'Sign in to sync reading across devices',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: _heroGold,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResumeContent() {
    final headlineText = surahNameLabel.trim().isNotEmpty
        ? '$mainTitle · $surahNameLabel'
        : mainTitle;
    final switchLabel = isMushaf
        ? (isThai ? 'สลับเป็นความหมาย' : 'Switch to Meaning')
        : (isThai ? 'สลับเป็นมุศหัฟ' : 'Switch to Mushaf');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMushaf
                    ? Icons.import_contacts_rounded
                    : Icons.menu_book_rounded,
                size: 20,
                color: Colors.white,
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
                        flex: 3,
                        child: Text(
                          modeBadge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.80),
                          ),
                        ),
                      ),
                      if (arabicSurahName.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(
                                arabicSurahName,
                                textDirection: TextDirection.rtl,
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: 'UthmanicHafs',
                                  fontSize: 15,
                                  height: 1.15,
                                  color: Colors.white.withValues(alpha: 0.90),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    headlineText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subDetail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: _heroIvory,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _heroBgLight,
              ),
            ),
          ],
        ),
        if (progressFraction != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progressFraction!.clamp(0.0, 1.0),
              minHeight: 4.5,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(_heroIvory),
            ),
          ),
        ],
        if (onSwitchMode != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  contextTag.trim().isNotEmpty
                      ? contextTag
                      : (isThai ? 'แตะเพื่ออ่านต่อ' : 'Tap to continue'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: InkWell(
                  onTap: onSwitchMode,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          switchLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _heroIvory.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 14,
                          color: _heroIvory.withValues(alpha: 0.95),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFirstTimeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modeBadge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mainTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subDetail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            if (arabicSurahName.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  arabicSurahName,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 20,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final meaningButton = FilledButton(
              onPressed: onStartMeaning,
              style: FilledButton.styleFrom(
                backgroundColor: _heroIvory,
                foregroundColor: _heroBgLight,
                elevation: 0,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              child: Text(
                isThai ? 'อ่านแบบความหมาย' : 'Read Meaning',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansThai(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            );
            final mushafButton = OutlinedButton(
              onPressed: onStartMushaf,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 42),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              child: Text(
                isThai ? 'เปิดมุศหัฟ' : 'Open Mushaf',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansThai(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            );
            if (constraints.maxWidth < 300) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  meaningButton,
                  const SizedBox(height: 8),
                  mushafButton,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: meaningButton),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: mushafButton),
              ],
            );
          },
        ),
      ],
    );
  }
}
