import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

/// Editorial dialog prompting the user to install an optional or required app update.
class AppUpdateDialog extends StatelessWidget {
  final AppUpdateCheckResult result;
  final Future<bool> Function(String url)? onLaunchStore;
  final Future<void> Function(AppVersionConfig config)? onDismissLater;

  const AppUpdateDialog({
    super.key,
    required this.result,
    this.onLaunchStore,
    this.onDismissLater,
  });

  /// Presents the update modal, disabling dismissal when [result.isForced] is true.
  static Future<void> show(
    BuildContext context, {
    required AppUpdateCheckResult result,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !result.isForced,
      builder: (_) => AppUpdateDialog(result: result),
    );
  }

  Future<void> _handleUpdatePressed(
    BuildContext context,
    AppVersionConfig config,
    AppThemeColors colors,
    bool isThai,
  ) async {
    final launched = await (onLaunchStore?.call(config.updateUrl) ??
        AppUpdateService.instance.openUpdateStore(config.updateUrl));
    if (!context.mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isThai
                ? 'ไม่สามารถเปิดหน้าอัปเดตได้ กรุณาอัปเดตผ่าน App Store หรือ Google Play'
                : 'Unable to open the store page. Please update via App Store or Google Play.',
            style: GoogleFonts.notoSansThai(),
          ),
          backgroundColor: colors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!result.isForced) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleLaterPressed(
    BuildContext context,
    AppVersionConfig config,
  ) async {
    await (onDismissLater?.call(config) ??
        AppUpdateService.instance.dismissSoftUpdate(config));
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = result.config;
    if (config == null) return const SizedBox.shrink();

    SettingsProvider? settings;
    try {
      settings = Provider.of<SettingsProvider>(context, listen: false);
    } catch (_) {
      settings = null;
    }

    final colors = settings?.getAppColors() ?? context.appColors;
    final isThai = (settings?.languageCode ?? 'th') == 'th';
    final isForced = result.isForced;
    final notes = config.releaseNotes(isThai);

    final badgeBg = isForced ? colors.mushafGoldSoft : colors.primaryLight;
    final badgeBorder =
        isForced ? colors.mushafGoldBorder : colors.primaryLightBorder;
    final badgeAccent = isForced ? colors.mushafGold : colors.primary;

    return PopScope(
      canPop: !isForced,
      child: Dialog(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: BorderSide(color: colors.borderSoft),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Icon(
                    isForced
                        ? Icons.system_security_update_warning_rounded
                        : Icons.system_update_rounded,
                    color: badgeAccent,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (isForced) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.mushafGoldSoft,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: colors.mushafGoldBorder),
                    ),
                    child: Text(
                      isThai ? 'จำเป็นต้องอัปเดต' : 'Required Update',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.mushafGold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                config.title(isThai),
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansThai(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.textStrong,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Text(
                    'v${result.currentVersion} (${result.currentBuildNumber})  →  v${config.latestVersion} (${config.latestBuildNumber})',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                config.message(isThai),
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansThai(
                  fontSize: 13.5,
                  height: 1.5,
                  color: colors.textMuted,
                ),
              ),
              if (notes != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isThai ? 'สิ่งใหม่ในเวอร์ชันนี้' : "What's New",
                        style: GoogleFonts.notoSansThai(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textStrong,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: SingleChildScrollView(
                          child: Text(
                            notes,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12.5,
                              height: 1.5,
                              color: colors.foreground,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.textInverse,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                onPressed: () => _handleUpdatePressed(
                  context,
                  config,
                  colors,
                  isThai,
                ),
                child: Text(
                  isThai ? 'อัปเดตตอนนี้' : 'Update Now',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isForced) ...[
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                  onPressed: () => _handleLaterPressed(context, config),
                  child: Text(
                    isThai ? 'ไว้ภายหลัง' : 'Later',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
