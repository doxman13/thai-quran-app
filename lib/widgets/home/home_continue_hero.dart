import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// Editorial "Continue Reading" hero card anchoring the Home screen.
class HomeContinueHero extends StatelessWidget {
  final bool hasHistory;
  final bool isMushaf;
  final String modeBadge;
  final String mainTitle;
  final String subDetail;
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
    required this.mainTitle,
    required this.subDetail,
    required this.isSignedIn,
    required this.isThai,
    required this.onContinue,
    required this.onStartMeaning,
    required this.onStartMushaf,
    this.onSwitchMode,
    this.onSignInTap,
  });

  static const Color _heroBgLight = Color(0xFF0E5A4A);
  static const Color _heroBgDark = Color(0xFF132D26);
  static const Color _heroBorderDark = Color(0xFF233A33);
  static const Color _heroGold = Color(0xFFD4A853);
  static const Color _heroGoldTextDark = Color(0xFF1C2520);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _heroBgDark : _heroBgLight;
    final borderColor =
        isDark ? _heroBorderDark : Colors.white.withValues(alpha: 0.14);

    return Semantics(
      container: true,
      label: '$modeBadge: $mainTitle',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: borderColor),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -6,
                bottom: -14,
                child: IgnorePointer(
                  child: Text(
                    'ٱقْرَأْ',
                    style: TextStyle(
                      fontFamily: 'UthmanicHafs',
                      fontSize: 94,
                      color: _heroGold.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: _heroGold.withValues(alpha: 0.40),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isMushaf
                                ? Icons.import_contacts_rounded
                                : Icons.menu_book_rounded,
                            size: 14,
                            color: _heroGold,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              modeBadge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSansThai(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      mainTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subDetail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!hasHistory)
                      _buildInitialButtons()
                    else
                      _buildResumeButtons(),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final meaningButton = FilledButton.icon(
          onPressed: onStartMeaning,
          icon: const Icon(Icons.menu_book_rounded, size: 18),
          label: Text(
            isThai ? 'อ่านแบบความหมาย' : 'Read with Meaning',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansThai(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _heroBgLight,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
        );
        final mushafButton = OutlinedButton.icon(
          onPressed: onStartMushaf,
          icon: const Icon(Icons.import_contacts_rounded, size: 18),
          label: Text(
            isThai ? 'เปิดมุศหัฟ' : 'Open Mushaf',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansThai(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
        );

        if (constraints.maxWidth < 340) {
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
            Expanded(child: meaningButton),
            const SizedBox(width: 10),
            Expanded(child: mushafButton),
          ],
        );
      },
    );
  }

  Widget _buildResumeButtons() {
    final continueButton = FilledButton.icon(
      onPressed: onContinue,
      icon: const Icon(Icons.play_arrow_rounded, size: 20),
      label: Text(
        isThai ? 'อ่านต่อจากจุดเดิม' : 'Continue Reading',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.notoSansThai(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: _heroGold,
        foregroundColor: _heroGoldTextDark,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
    );

    if (onSwitchMode == null) {
      return SizedBox(width: double.infinity, child: continueButton);
    }

    final switchLabel = isMushaf
        ? (isThai ? 'ความหมาย' : 'Meaning')
        : (isThai ? 'มุศหัฟ' : 'Mushaf');
    final switchButton = OutlinedButton.icon(
      onPressed: onSwitchMode,
      icon: Icon(
        isMushaf ? Icons.menu_book_rounded : Icons.import_contacts_rounded,
        size: 16,
      ),
      label: Text(
        switchLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.notoSansThai(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.10),
        minimumSize: const Size(0, 46),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.30)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              continueButton,
              const SizedBox(height: 8),
              switchButton,
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: continueButton),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: switchButton),
          ],
        );
      },
    );
  }
}
