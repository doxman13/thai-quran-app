import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/thai_text_protection_provider.dart';
import '../../theme/app_theme.dart';

/// Refined emerald "Continue Reading" card with dominant reading position,
/// quiet timestamp metadata, current mode tag, and instant mode switching.
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasHistory)
                  _buildFirstTimeContent()
                else
                  _buildResumeContent(),
                if (!isSignedIn && onSignInTap != null) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: onSignInTap,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Container(
                      padding: const EdgeInsets.only(top: 9),
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
                            size: 14,
                            color: _heroGold,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              isThai
                                  ? 'เข้าสู่ระบบเพื่อซิงก์การอ่านข้ามอุปกรณ์'
                                  : 'Sign in to sync reading across devices',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
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
    final activeModeLabel = contextTag.trim().isNotEmpty
        ? contextTag.trim()
        : (isMushaf
            ? (isThai ? 'มุศหัฟ' : 'Mushaf')
            : (isThai ? 'ความหมาย' : 'Meaning'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                modeBadge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansThai(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.80),
                ),
              ),
            ),
            if (arabicSurahName.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: Text(
                  arabicSurahName,
                  textDirection: TextDirection.rtl,
                  locale: const Locale('ar'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 15,
                    height: 1.1,
                    letterSpacing: 0,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headlineText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    locale: isThai ? ThaiTextProtectionProvider.thaiLocale : null,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subDetail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progressFraction!.clamp(0.0, 1.0),
              minHeight: 3.5,
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              valueColor: const AlwaysStoppedAnimation<Color>(_heroIvory),
            ),
          ),
        ],
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMushaf
                        ? Icons.import_contacts_rounded
                        : Icons.menu_book_rounded,
                    size: 13.5,
                    color: _heroGold,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      activeModeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onSwitchMode != null) ...[
              const SizedBox(width: 8),
              InkWell(
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
                          color: _heroIvory.withValues(alpha: 0.94),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 14,
                        color: _heroIvory.withValues(alpha: 0.94),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modeBadge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mainTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 19,
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
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            if (arabicSurahName.trim().isNotEmpty) ...[
              const SizedBox(width: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  arabicSurahName,
                  textDirection: TextDirection.rtl,
                  locale: const Locale('ar'),
                  style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 19,
                    letterSpacing: 0,
                    color: Colors.white.withValues(alpha: 0.90),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 13),
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
