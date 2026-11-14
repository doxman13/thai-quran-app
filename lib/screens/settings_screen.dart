import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/quran_foundation_repository.dart';
import '../data/quran_repository.dart';
import '../database/hifz_repository.dart';
import '../providers/local_reading_provider.dart';
import '../providers/mushaf_audio_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/supabase_provider.dart';
import '../providers/translation_manager_provider.dart';
import '../shared/shared.dart';
import '../theme/app_theme.dart';
import '../widgets/support_dialog.dart';
import '../widgets/tajweed_color_guide_sheet.dart';
import '../widgets/translation_download_dialog.dart';
import '../widgets/auth_bottom_sheet.dart';
import 'bookmarks_screen.dart';
import 'goals_screen.dart';
import 'hifz_settings_screen.dart' show BleDeviceManagementUI;
import 'tadabbur_private_screen.dart';

enum SettingsCategoryTab {
  profile,
  reading,
  translations,
  appearance,
  hifz,
}

class SettingsScreen extends StatefulWidget {
  final QuranRepository? repository;
  final SettingsCategoryTab initialCategory;

  const SettingsScreen({
    super.key,
    this.repository,
    this.initialCategory = SettingsCategoryTab.profile,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final QuranFoundationRepository _foundationRepository =
      QuranFoundationRepository();
  bool _isSyncing = false;

  static const String _previewArabic = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
  static const String _previewTranslationTh =
      'ด้วยพระนามของอัลลอฮฺ ผู้ทรงกรุณาปรานี ผู้ทรงเมตตาเสมอ';

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != SettingsCategoryTab.profile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInitialCategoryNavigation();
      });
    }
  }

  void _handleInitialCategoryNavigation() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final colors = settings.getAppColors();
    final isThai = settings.languageCode == 'th';

    switch (widget.initialCategory) {
      case SettingsCategoryTab.hifz:
        _showHifzDevicesSheet(context, colors, isThai);
        break;
      case SettingsCategoryTab.reading:
        _showTypographySheet(context, settings, colors, isThai);
        break;
      case SettingsCategoryTab.translations:
        _showTranslationsSheet(context, settings, colors, isThai);
        break;
      case SettingsCategoryTab.appearance:
        _showAppearanceSheet(context, settings, colors, isThai);
        break;
      default:
        break;
    }
  }

  // ── Sync Handler ─────────────────────────────────────────────────────────────
  Future<void> _handleManualSync(
    BuildContext context,
    SupabaseProvider supabaseProv,
    SettingsProvider settingsProv,
    LocalReadingProvider readingProv,
    MushafReadingProvider mushafProv,
    NotesProvider notesProv,
    StatsProvider statsProv,
    bool isThai,
  ) async {
    if (!supabaseProv.isLoggedIn) {
      _showAuthBottomSheet(context, isThai, settingsProv.getAppColors());
      return;
    }

    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      await readingProv.flushPendingProfileSyncs();
      await readingProv.flushPendingRecentReadingSync();
      await readingProv.flushPendingReadingStateSync();
      await mushafProv.flushPendingProfileSyncs();
      await mushafProv.flushPendingRecentReadingSync();
      await statsProv.flushPendingSave();

      await settingsProv.syncWithSupabase(supabaseProv.userId);
      await readingProv.syncBookmarksAndProfilesWithSupabase(
        supabaseProv.userId,
      );
      await readingProv.syncReadingStateWithSupabase(supabaseProv.userId);
      await mushafProv.syncWithSupabase(supabaseProv.userId);
      await notesProv.syncWithSupabase();
      await statsProv.syncWithSupabase(supabaseProv.userId);
      await HifzRepository.instance.syncWithSupabase();
      await HifzRepository.instance.syncHistoryWithSupabase();

      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              isThai
                  ? 'ซิงค์ข้อมูลกับคลาวด์สำเร็จเรียบร้อย'
                  : 'Cloud data synchronized successfully',
              style: GoogleFonts.notoSansThai(),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              isThai ? 'เกิดข้อผิดพลาดในการซิงค์: $e' : 'Sync error: $e',
              style: GoogleFonts.notoSansThai(),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ── Reset Defaults ───────────────────────────────────────────────────────────
  Future<void> _confirmAndResetDefaults(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    bool isThai,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(color: colors.borderSoft),
        ),
        title: Text(
          isThai ? 'คืนค่าเริ่มต้นทั้งหมด?' : 'Reset All Settings?',
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: colors.textStrong,
          ),
        ),
        content: Text(
          isThai
              ? 'ขนาดตัวอักษร ธีมแสดงผล คำแปล และค่าการอ่านจะถูกคืนเป็นค่ามาตรฐานดั้งเดิม (ไม่กระทบบุ๊กมาร์กและบันทึก)'
              : 'Typography, theme, active translations, and reading options will be restored to defaults. Your bookmarks and notes will not be affected.',
          style: GoogleFonts.notoSansThai(
            fontSize: 13,
            color: colors.textMuted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isThai ? 'ยกเลิก' : 'Cancel',
              style: GoogleFonts.notoSansThai(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isThai ? 'คืนค่าเริ่มต้น' : 'Reset to Defaults',
              style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await settings.resetToDefaults();
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              isThai
                  ? 'คืนค่าเริ่มต้นเรียบร้อยแล้ว'
                  : 'Settings restored to defaults',
              style: GoogleFonts.notoSansThai(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Sign Out & Delete Account ───────────────────────────────────────────────
  Future<void> _confirmSignOut(
    BuildContext context,
    SupabaseProvider supabaseProv,
    AppThemeColors colors,
    bool isThai,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(color: colors.borderSoft),
        ),
        title: Text(
          isThai ? 'ออกจากระบบ?' : 'Sign Out?',
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: colors.textStrong,
          ),
        ),
        content: Text(
          isThai
              ? 'คุณต้องการออกจากระบบบัญชีนี้ใช่หรือไม่? ข้อมูลในอุปกรณ์นี้จะยังคงอยู่และสามารถซิงค์ได้อีกครั้งเมื่อเข้าสู่ระบบ'
              : 'Are you sure you want to sign out? Your local data will remain saved on this device.',
          style: GoogleFonts.notoSansThai(
            fontSize: 13,
            color: colors.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isThai ? 'ยกเลิก' : 'Cancel',
              style: GoogleFonts.notoSansThai(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isThai ? 'ออกจากระบบ' : 'Sign Out',
              style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await supabaseProv.signOut();
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              isThai ? 'ออกจากระบบเรียบร้อยแล้ว' : 'Signed out successfully',
              style: GoogleFonts.notoSansThai(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    SupabaseProvider supabaseProv,
    AppThemeColors colors,
    bool isThai,
  ) async {
    final localReadingProv = context.read<LocalReadingProvider>();
    final mushafProv = context.read<MushafReadingProvider>();
    final notesProv = context.read<NotesProvider>();
    final statsProv = context.read<StatsProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(color: colors.borderSoft),
        ),
        title: Text(
          isThai ? 'ลบบัญชีผู้ใช้ถาวร?' : 'Delete Account Permanently?',
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: const Color(0xFFDC2626),
          ),
        ),
        content: Text(
          isThai
              ? 'การกระทำนี้ไม่สามารถย้อนกลับได้ ข้อมูลการซิงค์คลาวด์ บุ๊กมาร์ก และบันทึกตะดับบุรที่เชื่อมโยงกับบัญชีนี้จะถูกนำออกจากระบบ'
              : 'This action cannot be undone. All cloud backups, bookmarks, and sync records tied to this account will be permanently removed.',
          style: GoogleFonts.notoSansThai(
            fontSize: 13,
            color: colors.textMuted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isThai ? 'ยกเลิก' : 'Cancel',
              style: GoogleFonts.notoSansThai(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isThai ? 'ยืนยันลบบัญชี' : 'Delete Account',
              style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await supabaseProv.deleteAccount();
      if (!mounted) return;

      if (ok) {
        await localReadingProv.clearAllLocal();
        await mushafProv.clearAllLocal();
        await notesProv.clearAllLocal();
        await statsProv.clearAllLocal();
        await HifzRepository.instance.clearAllLocalData();

        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(
                isThai
                    ? 'ลบบัญชีและล้างข้อมูลทั้งหมดเรียบร้อยแล้ว'
                    : 'Account deleted and all data cleared',
                style: GoogleFonts.notoSansThai(),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(
                isThai
                    ? 'เกิดข้อผิดพลาดในการลบบัญชี โปรดลองใหม่อีกครั้ง'
                    : 'Failed to delete account. Please try again.',
                style: GoogleFonts.notoSansThai(),
              ),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ── Navigation Shortcuts ───────────────────────────────────────────────────
  void _openGoals() {
    final supabaseProv = Provider.of<SupabaseProvider>(context, listen: false);
    if (!supabaseProv.isLoggedIn) {
      AuthRequiredDialog.show(
        context,
        featureName: 'เป้าหมายการอ่าน (Reading Goals)',
        reason:
            'การสร้างและติดตามเป้าหมายการอ่านจำเป็นต้องเข้าสู่ระบบ เพื่อบันทึกความคืบหน้าบนคลาวด์',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoalsScreen(
          repository: widget.repository ?? QuranRepository(),
          foundationRepository: _foundationRepository,
        ),
      ),
    );
  }

  void _openBookmarks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookmarksScreen(
          repository: widget.repository ?? QuranRepository(),
        ),
      ),
    );
  }

  void _openTadabburNotes() {
    final supabaseProv = Provider.of<SupabaseProvider>(context, listen: false);
    if (!supabaseProv.isLoggedIn) {
      AuthRequiredDialog.show(
        context,
        featureName: 'บันทึกตะดับบุร (Tadabbur Notes)',
        reason:
            'การดูและจัดการบันทึกตะดับบุรจำเป็นต้องเข้าสู่ระบบ เพื่อจัดเก็บข้อมูลอย่างปลอดภัยบนคลาวด์',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TadabburPrivateScreen(
          repository: widget.repository ?? QuranRepository(),
        ),
      ),
    );
  }

  // ── Main Build Method ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final supabaseProv = Provider.of<SupabaseProvider>(context);
    final readingProv = Provider.of<LocalReadingProvider>(context);
    final mushafProv = Provider.of<MushafReadingProvider>(context);
    final notesProv = Provider.of<NotesProvider>(context);
    final statsProv = Provider.of<StatsProvider>(context);
    final colors = settings.getAppColors();
    final isThai = settings.languageCode == 'th';
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: canPop
          ? AppBar(
              backgroundColor: colors.background,
              elevation: 0,
              foregroundColor: colors.primary,
              title: Text(
                isThai ? 'โปรไฟล์ & การตั้งค่า' : 'Profile & Settings',
                style: GoogleFonts.notoSansThai(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Profile Avatar & User Identity ────────────────────────
              _buildProfileHeader(
                context,
                supabaseProv,
                settings,
                colors,
                isThai,
              ),
              const SizedBox(height: 20),

              // ── 2. Category: ACCOUNT ─────────────────────────────────────
              _buildSectionHeader(isThai ? 'บัญชีผู้ใช้' : 'ACCOUNT', colors),
              const SizedBox(height: 8),
              _buildGroupCard(
                colors: colors,
                children: [
                  _RevealListTile(
                    icon: Icons.star_rounded,
                    iconBg: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    title: isThai ? 'สถานะบัญชี' : 'Membership',
                    subtitle: supabaseProv.isLoggedIn
                        ? (isThai
                            ? 'บัญชีสมาชิกคลาวด์'
                            : 'Cloud Account')
                        : (isThai
                            ? 'ผู้ใช้งานทั่วไป (ออฟไลน์)'
                            : 'Local Guest Mode'),
                    trailing: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFF9CA3AF),
                          ),
                    onTap: () => _handleManualSync(
                      context,
                      supabaseProv,
                      settings,
                      readingProv,
                      mushafProv,
                      notesProv,
                      statsProv,
                      isThai,
                    ),
                  ),
                  _RevealListTile(
                    icon: Icons.person_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                    title: isThai ? 'ข้อมูลโปรไฟล์' : 'Edit Profile',
                    subtitle: supabaseProv.isLoggedIn
                        ? (supabaseProv.displayName.isNotEmpty
                            ? supabaseProv.displayName
                            : (supabaseProv.userEmail.isNotEmpty
                                ? supabaseProv.userEmail
                                : (isThai ? 'แก้ไขชื่อ & บัญชี' : 'Edit details')))
                        : (isThai
                            ? 'เข้าสู่ระบบ / ลงทะเบียน'
                            : 'Sign In / Register'),
                    onTap: () {
                      if (supabaseProv.isLoggedIn) {
                        _showEditDisplayNameDialog(
                          context,
                          supabaseProv,
                          colors,
                          isThai,
                        );
                      } else {
                        _showAuthBottomSheet(context, isThai, colors);
                      }
                    },
                  ),
                  _RevealListTile(
                    icon: Icons.timer_outlined,
                    iconBg: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF16A34A),
                    title: isThai ? 'เป้าหมายการอ่าน' : 'Reading Goals',
                    subtitle: isThai
                        ? 'จัดการเป้าหมายและแผนการอ่าน'
                        : 'Manage reading goals & plans',
                    onTap: _openGoals,
                  ),
                  _RevealListTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconBg: const Color(0xFFF3E8FF),
                    iconColor: const Color(0xFF9333EA),
                    title: isThai ? 'บันทึกตะดับบุร' : 'My Tadabbur Notes',
                    subtitle: isThai
                        ? '${notesProv.personalNotes.length} บันทึกข้อคิด'
                        : '${notesProv.personalNotes.length} notes',
                    onTap: _openTadabburNotes,
                  ),
                  _RevealListTile(
                    icon: Icons.bookmark_border_rounded,
                    iconBg: const Color(0xFFFFFBEB),
                    iconColor: const Color(0xFFB45309),
                    title: isThai ? 'ที่คั่นหน้า & ประวัติ' : 'Bookmarks & History',
                    subtitle: isThai
                        ? 'ดูรายการที่คั่นและอ่านค้าง'
                        : 'Saved bookmarks & history',
                    onTap: _openBookmarks,
                  ),
                  _RevealListTile(
                    icon: Icons.devices_rounded,
                    iconBg: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: isThai ? 'อุปกรณ์ฮิฟซ์ & รีโมท' : 'Manage Devices',
                    subtitle: isThai
                        ? 'เชื่อมต่อรีโมทเปลี่ยนหน้าบลูทูธ'
                        : 'Bluetooth page turners',
                    onTap: () => _showHifzDevicesSheet(context, colors, isThai),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 5. Category: APPEARANCE ──────────────────────────────────
              _buildSectionHeader(isThai ? 'การแสดงผล' : 'APPEARANCE', colors),
              const SizedBox(height: 8),
              _buildGroupCard(
                colors: colors,
                children: [
                  _RevealListTile(
                    icon: Icons.palette_outlined,
                    iconBg: const Color(0xFFFFEDD5),
                    iconColor: const Color(0xFFEA580C),
                    title: isThai ? 'ธีมหน้าจอ' : 'Appearance',
                    subtitle: settings.isDarkMode
                        ? (isThai ? 'โหมดมืด (Dark)' : 'Dark')
                        : (isThai ? 'โหมดสว่าง (Light)' : 'Light'),
                    onTap: () =>
                        _showAppearanceSheet(context, settings, colors, isThai),
                  ),
                  _RevealListTile(
                    icon: Icons.view_compact_alt_rounded,
                    iconBg: const Color(0xFFFCE7F3),
                    iconColor: const Color(0xFFDB2777),
                    title: isThai ? 'รูปแบบการแสดงผล' : 'Display Mode',
                    subtitle: settings.readingDisplayMode == SettingsProvider.quranOnlyMode
                        ? (isThai ? 'เฉพาะภาษาอาหรับ' : 'Arabic Only')
                        : settings.readingDisplayMode == SettingsProvider.translationOnlyMode
                            ? (isThai ? 'เฉพาะคำแปล' : 'Translation Only')
                            : (isThai ? 'อาหรับพร้อมคำแปล' : 'Arabic & Translation'),
                    onTap: () => _showDisplayModeSheet(
                      context,
                      settings,
                      colors,
                      isThai,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 6. Category: READING PREFERENCES ─────────────────────────
              _buildSectionHeader(
                isThai ? 'การตั้งค่าการอ่าน' : 'READING PREFERENCES',
                colors,
              ),
              const SizedBox(height: 8),
              _buildGroupCard(
                colors: colors,
                children: [
                  _RevealListTile(
                    icon: Icons.language_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                    title: isThai ? 'ภาษาของแอป' : 'App Language',
                    subtitle:
                        settings.languageCode == 'th' ? 'ภาษาไทย' : 'English',
                    onTap: () =>
                        _showLanguageSheet(context, settings, colors, isThai),
                  ),
                  _RevealListTile(
                    icon: Icons.text_fields_rounded,
                    iconBg: const Color(0xFFE0E7FF),
                    iconColor: const Color(0xFF4F46E5),
                    title: isThai ? 'แบบอักษร & ขนาด' : 'Typography & Font Size',
                    subtitle: isThai
                        ? 'อาหรับ ${settings.arabicFontSize.round()}px • แปล ${settings.translationFontSize.round()}px'
                        : 'Arabic ${settings.arabicFontSize.round()}px • Trans ${settings.translationFontSize.round()}px',
                    onTap: () => _showTypographySheet(
                      context,
                      settings,
                      colors,
                      isThai,
                    ),
                  ),
                  _RevealListTile(
                    icon: Icons.menu_book_rounded,
                    iconBg: const Color(0xFFEAF2EE),
                    iconColor: const Color(0xFF0E5A4A),
                    title: isThai ? 'ชุดคำแปลอัลกุรอาน' : 'Translations',
                    subtitle: _resolveTranslationDisplayName(
                      settings.primaryTranslationId,
                      settings.languageCode,
                    ),
                    onTap: () => _showTranslationsSheet(
                      context,
                      settings,
                      colors,
                      isThai,
                    ),
                  ),
                  _RevealListTile(
                    icon: Icons.graphic_eq_rounded,
                    iconBg: const Color(0xFFFCE7F3),
                    iconColor: const Color(0xFFDB2777),
                    title: isThai ? 'เสียงผู้อ่านกุรอาน' : 'Recitation Voice',
                    subtitle: settings.reciterName,
                    onTap: () => _showReciterSheet(
                      context,
                      settings,
                      colors,
                      isThai,
                    ),
                  ),
                  _RevealListTile(
                    icon: Icons.translate_rounded,
                    iconBg: const Color(0xFFF0FDFA),
                    iconColor: const Color(0xFF0F766E),
                    title: isThai ? 'คำแปลทีละคำ (WBW)' : 'Word by Word',
                    subtitle: isThai
                        ? 'แสดงความหมายใต้คำศัพท์'
                        : 'Show translation per word',
                    trailing: Switch.adaptive(
                      value: settings.showWordByWord,
                      activeThumbColor: colors.primary,
                      onChanged: (val) => settings.toggleShowWordByWord(val),
                    ),
                  ),
                  _RevealListTile(
                    icon: Icons.auto_awesome_rounded,
                    iconBg: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFB45309),
                    title: isThai ? 'สัญลักษณ์สีตัจญ์วีด' : 'Tajweed Colors',
                    subtitle: isThai
                        ? 'ไฮไลต์กฎการออกเสียง (แตะดูกฎ)'
                        : 'Color pronunciation rules',
                    trailing: Switch.adaptive(
                      value: settings.showTajweedColors,
                      activeThumbColor: colors.primary,
                      onChanged: (val) => settings.setShowTajweedColors(val),
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: colors.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => TajweedColorGuideSheet(colors: colors),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 7. Category: STORAGE & DATA ──────────────────────────────
              _buildSectionHeader(
                isThai ? 'ข้อมูลและระบบ' : 'STORAGE & DATA',
                colors,
              ),
              const SizedBox(height: 8),
              _buildGroupCard(
                colors: colors,
                children: [
                  _RevealListTile(
                    icon: Icons.restart_alt_rounded,
                    iconBg: const Color(0xFFF3F4F6),
                    iconColor: const Color(0xFF4B5563),
                    title: isThai ? 'คืนค่าเริ่มต้น' : 'Reset Defaults',
                    subtitle: isThai
                        ? 'รีเซ็ตการตั้งค่ากลับสู่ค่ามาตรฐาน'
                        : 'Restore settings to default',
                    onTap: () => _confirmAndResetDefaults(
                      context,
                      settings,
                      colors,
                      isThai,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 8. Category: SUPPORT ─────────────────────────────────────
              _buildSectionHeader(isThai ? 'สนับสนุน & ข้อมูล' : 'SUPPORT', colors),
              const SizedBox(height: 8),
              _buildGroupCard(
                colors: colors,
                children: [
                  _RevealListTile(
                    icon: Icons.mail_outline_rounded,
                    iconBg: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: isThai ? 'ส่งความคิดเห็น & แจ้งปัญหา' : 'Send Feedback',
                    subtitle: isThai
                        ? 'ช่วยเราพัฒนาแอปให้ดียิ่งขึ้น'
                        : 'Help us improve the app',
                    onTap: () {
                      launchUrl(
                        Uri.parse(
                          'mailto:support@quran-th.com?subject=Thai%20Quran%20App%20Feedback',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                  _RevealListTile(
                    icon: Icons.favorite_outline_rounded,
                    iconBg: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFF8A6530),
                    title: isThai ? 'สนับสนุนผู้พัฒนา' : 'Support Developer',
                    subtitle: isThai
                        ? 'ร่วมสนับสนุนโครงการอัลกุรอาน'
                        : 'Support ongoing development',
                    onTap: () => SupportDialog.show(context),
                  ),
                  _RevealListTile(
                    icon: Icons.info_outline_rounded,
                    iconBg: const Color(0xFFF3F4F6),
                    iconColor: const Color(0xFF4B5563),
                    title: isThai ? 'เกี่ยวกับแอปพลิเคชัน' : 'About',
                    subtitle: 'Thai Quran v1.0.0',
                    onTap: () => _showAboutSheet(context, colors, isThai),
                  ),
                  _RevealListTile(
                    icon: Icons.privacy_tip_outlined,
                    iconBg: const Color(0xFFF3F4F6),
                    iconColor: const Color(0xFF4B5563),
                    title: isThai ? 'นโยบายความเป็นส่วนตัว' : 'Privacy Policy',
                    subtitle: 'https://quran-th.com/privacy',
                    onTap: () async {
                      final uri = Uri.parse('https://quran-th.com/privacy');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  if (supabaseProv.isLoggedIn) ...[
                    _RevealListTile(
                      icon: Icons.delete_outline_rounded,
                      iconBg: const Color(0xFFFEE2E2),
                      iconColor: const Color(0xFFDC2626),
                      title: isThai ? 'ลบบัญชีผู้ใช้' : 'Delete Account',
                      subtitle: isThai
                          ? 'ลบข้อมูลและประวัติทั้งหมดถาวร'
                          : 'Permanently delete account',
                      isDestructive: true,
                      onTap: () => _confirmDeleteAccount(
                        context,
                        supabaseProv,
                        colors,
                        isThai,
                      ),
                    ),
                    _RevealListTile(
                      icon: Icons.logout_rounded,
                      iconBg: const Color(0xFFFEE2E2),
                      iconColor: const Color(0xFFDC2626),
                      title: isThai ? 'ออกจากระบบ' : 'Sign Out',
                      subtitle: isThai
                          ? 'ออกจากบัญชีในอุปกรณ์นี้'
                          : 'Sign out on this device',
                      isDestructive: true,
                      onTap: () => _confirmSignOut(
                        context,
                        supabaseProv,
                        colors,
                        isThai,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Widget ──────────────────────────────────────────────────────────
  Widget _buildProfileHeader(
    BuildContext context,
    SupabaseProvider supabaseProv,
    SettingsProvider settings,
    AppThemeColors colors,
    bool isThai,
  ) {
    final isLoggedIn = supabaseProv.isLoggedIn;
    final displayName = isLoggedIn
        ? (supabaseProv.displayName.isNotEmpty
            ? supabaseProv.displayName
            : (supabaseProv.userEmail.isNotEmpty
                ? supabaseProv.userEmail.split('@').first
                : (isThai ? 'ผู้ใช้งาน' : 'User')))
        : (isThai ? 'ผู้ใช้งานทั่วไป' : 'Guest User');
    final subtitle = isLoggedIn
        ? (supabaseProv.userEmail.isNotEmpty
            ? supabaseProv.userEmail
            : (isThai ? 'เข้าสู่ระบบแล้ว' : 'Signed in'))
        : (isThai
            ? 'เข้าสู่ระบบเพื่อสำรองข้อมูลและซิงค์คลาวด์'
            : 'Sign in to sync your data across devices');

    final initialLetter = displayName.isNotEmpty
        ? displayName.characters.first.toUpperCase()
        : 'Q';

    return Column(
      children: [
        // Avatar circle with pencil badge
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () {
                  if (isLoggedIn) {
                    _showEditDisplayNameDialog(
                      context,
                      supabaseProv,
                      colors,
                      isThai,
                    );
                  } else {
                    _showAuthBottomSheet(context, isThai, colors);
                  }
                },
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EBE1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE8DACB),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isLoggedIn
                        ? Text(
                            initialLetter,
                            style: GoogleFonts.notoSansThai(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF8A6530),
                            ),
                          )
                        : const Icon(
                            Icons.person_outline_rounded,
                            size: 42,
                            color: Color(0xFF8A6530),
                          ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: 0,
                child: GestureDetector(
                  onTap: () {
                    if (isLoggedIn) {
                      _showEditDisplayNameDialog(
                        context,
                        supabaseProv,
                        colors,
                        isThai,
                      );
                    } else {
                      _showAuthBottomSheet(context, isThai, colors);
                    }
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A3825),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Display Name
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.notoSansThai(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: colors.textStrong,
          ),
        ),
        const SizedBox(height: 4),

        // Subtitle / Email
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.notoSansThai(
            fontSize: 13,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 12),

        // Status Badge Pill
        InkWell(
          onTap: () {
            if (isLoggedIn) {
              _handleManualSync(
                context,
                supabaseProv,
                settings,
                Provider.of<LocalReadingProvider>(context, listen: false),
                Provider.of<MushafReadingProvider>(context, listen: false),
                Provider.of<NotesProvider>(context, listen: false),
                Provider.of<StatsProvider>(context, listen: false),
                isThai,
              );
            } else {
              _showAuthBottomSheet(context, isThai, colors);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 6),
                Text(
                  isLoggedIn
                      ? (isThai
                          ? 'บัญชีคลาวด์ (ซิงค์แล้ว)'
                          : 'Cloud Member (Synced)')
                      : (isThai
                          ? 'โหมดออฟไลน์ (แตะเพื่อเชื่อมต่อ)'
                          : 'Offline Mode (Tap to sync)'),
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Section Header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: GoogleFonts.notoSansThai(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF8A6530),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // ── Group Card Container ───────────────────────────────────────────────────
  Widget _buildGroupCard({
    required AppThemeColors colors,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.borderSoft.withValues(alpha: 0.7),
                  indent: 58,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  // ── Helper: Resolve Translation Name ───────────────────────────────────────
  String _resolveTranslationDisplayName(String id, String langCode) {
    final opt = TranslationConstants.getKnownOption(id);
    if (opt != null) {
      return opt.displayName(langCode);
    }
    return id == 'thai_v3'
        ? (langCode == 'th'
            ? 'ภาษาไทย (ฉบับสมาคมนักเรียนเก่าอาหรับฯ)'
            : 'Thai (Arab Alumni Association - King Fahd Complex)')
        : id;
  }

  // ── Bottom Sheet: Typography & Font Size ───────────────────────────────────
  void _showTypographySheet(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    bool isThai,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colors.borderSoft,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isThai
                              ? 'แบบอักษร & ขนาดตัวหนังสือ'
                              : 'Typography & Font Size',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: colors.textStrong,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Live Verse Preview Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: colors.borderSoft),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _previewArabic,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.amiri(
                              fontSize: settings.arabicFontSize,
                              color: colors.textStrong,
                              height: 1.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _previewTranslationTh,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.notoSansThai(
                              fontSize: settings.translationFontSize,
                              color: colors.textMuted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Arabic Font Size
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isThai ? 'ขนาดตัวอักษรภาษาอาหรับ' : 'Arabic Font Size',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textStrong,
                          ),
                        ),
                        Text(
                          '${settings.arabicFontSize.round()} px',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: settings.arabicFontSize,
                      min: 18.0,
                      max: 44.0,
                      activeColor: colors.primary,
                      onChanged: (val) {
                        settings.setArabicFontSize(val);
                        setSheetState(() {});
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [22.0, 28.0, 34.0, 40.0].map((sz) {
                        final isSel = (settings.arabicFontSize - sz).abs() < 2;
                        return InkWell(
                          onTap: () {
                            settings.setArabicFontSize(sz);
                            setSheetState(() {});
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSel ? colors.primary : colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${sz.round()}px',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSel ? Colors.white : colors.textStrong,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Translation Font Size
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isThai ? 'ขนาดตัวอักษรคำแปล' : 'Translation Font Size',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textStrong,
                          ),
                        ),
                        Text(
                          '${settings.translationFontSize.round()} px',
                          style: GoogleFonts.notoSansThai(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: settings.translationFontSize,
                      min: 12.0,
                      max: 26.0,
                      activeColor: colors.primary,
                      onChanged: (val) {
                        settings.setTranslationFontSize(val);
                        setSheetState(() {});
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [13.0, 15.0, 18.0, 22.0].map((sz) {
                        final isSel =
                            (settings.translationFontSize - sz).abs() < 1.5;
                        return InkWell(
                          onTap: () {
                            settings.setTranslationFontSize(sz);
                            setSheetState(() {});
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSel ? colors.primary : colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${sz.round()}px',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSel ? Colors.white : colors.textStrong,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Bottom Sheet: Appearance / Theme ───────────────────────────────────────
  void _showAppearanceSheet(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    bool isThai,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isThai ? 'เลือกธีมหน้าจอ' : 'Choose Appearance',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRadioTile(
                  title: isThai ? 'โหมดสว่าง (Light)' : 'Light',
                  subtitle: isThai ? 'พื้นหลังกระดาษนวลตา' : 'Warm paper tone',
                  icon: Icons.light_mode_outlined,
                  iconColor: const Color(0xFFEA580C),
                  isSelected: !settings.isDarkMode,
                  colors: colors,
                  onTap: () {
                    settings.toggleDarkMode(false);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
                _buildRadioTile(
                  title: isThai ? 'โหมดมืด (Dark)' : 'Dark',
                  subtitle: isThai ? 'มืดสนิทเพื่อการอ่านกลางคืน' : 'Comfortable for night reading',
                  icon: Icons.dark_mode_outlined,
                  iconColor: const Color(0xFF6366F1),
                  isSelected: settings.isDarkMode,
                  colors: colors,
                  onTap: () {
                    settings.toggleDarkMode(true);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Bottom Sheet: Display Mode ─────────────────────────────────────────────
  void _showDisplayModeSheet(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    bool isThai,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isThai ? 'รูปแบบการแสดงผลหน้าอ่าน' : 'Reading Display Mode',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRadioTile(
                  title: isThai ? 'อาหรับพร้อมคำแปล (มาตรฐาน)' : 'Arabic & Translation',
                  subtitle: isThai ? 'แสดงตัวบทอาหรับและคำแปลคู่กัน' : 'Display Arabic text with translations',
                  icon: Icons.menu_book_rounded,
                  iconColor: colors.primary,
                  isSelected: settings.readingDisplayMode == SettingsProvider.quranTranslationMode,
                  colors: colors,
                  onTap: () {
                    settings.setReadingDisplayMode(SettingsProvider.quranTranslationMode);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
                _buildRadioTile(
                  title: isThai ? 'เฉพาะภาษาอาหรับ (ท่องจำ)' : 'Arabic Only',
                  subtitle: isThai ? 'ซ่อนคำแปลเพื่อฝึกท่องจำ' : 'Hide translation for memorization',
                  icon: Icons.auto_stories_rounded,
                  iconColor: const Color(0xFF0284C7),
                  isSelected: settings.readingDisplayMode == SettingsProvider.quranOnlyMode,
                  colors: colors,
                  onTap: () {
                    settings.setReadingDisplayMode(SettingsProvider.quranOnlyMode);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
                _buildRadioTile(
                  title: isThai ? 'เฉพาะคำแปลภาษาไทย' : 'Translation Only',
                  subtitle: isThai ? 'อ่านความหมายอย่างต่อเนื่อง' : 'Read translation only',
                  icon: Icons.translate_rounded,
                  iconColor: const Color(0xFF8A6530),
                  isSelected: settings.readingDisplayMode == SettingsProvider.translationOnlyMode,
                  colors: colors,
                  onTap: () {
                    settings.setReadingDisplayMode(SettingsProvider.translationOnlyMode);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required AppThemeColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.08) : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected ? colors.primary : colors.borderSoft,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: colors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Bottom Sheet: App Language ─────────────────────────────────────────────
  void _showLanguageSheet(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    bool isThai,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isThai ? 'ภาษาของแอปพลิเคชัน' : 'App Language',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRadioTile(
                  title: 'ภาษาไทย (Thai)',
                  subtitle: 'แสดงเมนูและคำแนะนำเป็นภาษาไทย',
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF2563EB),
                  isSelected: settings.languageCode == 'th',
                  colors: colors,
                  onTap: () {
                    settings.setLanguageCode('th');
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
                _buildRadioTile(
                  title: 'English',
                  subtitle: 'Use English interface',
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF2563EB),
                  isSelected: settings.languageCode == 'en',
                  colors: colors,
                  onTap: () {
                    settings.setLanguageCode('en');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Bottom Sheet: Translations ─────────────────────────────────────────────
  void _showTranslationsSheet(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    bool isThai,
  ) {
    final transManager = Provider.of<TranslationManagerProvider>(
      context,
      listen: false,
    );
    final allOptions = TranslationConstants.getAllOptions(
      downloadedTranslations: transManager.downloadedTranslations,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: colors.borderSoft,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isThai
                                ? 'เลือกชุดคำแปลหลัก'
                                : 'Select Translation',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: colors.textStrong,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: allOptions.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: colors.borderSoft,
                          ),
                          itemBuilder: (context, idx) {
                            final opt = allOptions[idx];
                            final isSelected =
                                settings.primaryTranslationId == opt.id;
                            final isDownloaded =
                                transManager.isDownloaded(opt.id);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              title: Text(
                                opt.displayName(settings.languageCode),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? colors.primary
                                      : colors.textStrong,
                                ),
                              ),
                              subtitle: Text(
                                opt.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 12,
                                  color: colors.textMuted,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: colors.primary,
                                    )
                                  : (!isDownloaded
                                      ? Icon(
                                          Icons.download_for_offline_outlined,
                                          size: 20,
                                          color: colors.textMuted,
                                        )
                                      : null),
                              onTap: () async {
                                if (isDownloaded) {
                                  settings.updateTranslationSlot(
                                    'primary',
                                    opt.id,
                                  );
                                  transManager.loadTranslationIntoCache(opt.id);
                                  Navigator.pop(ctx);
                                } else {
                                  final downloaded =
                                      await TranslationDownloadDialog.show(
                                    context,
                                    option: opt,
                                    isPrimary: true,
                                  );
                                  if (downloaded) {
                                    setSheetState(() {});
                                    if (mounted) setState(() {});
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Bottom Sheet: Reciter Audio ────────────────────────────────────────────
  void _showReciterSheet(
    BuildContext context,
    SettingsProvider settings,
    AppThemeColors colors,
    bool isThai,
  ) {
    final mushafAudio = Provider.of<MushafAudioProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isThai ? 'เสียงผู้อ่านอัลกุรอาน' : 'Quran Reciter',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: 12),
                ...kSupportedReciters.map((reciter) {
                  final isSelected = settings.reciterId == reciter.id;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary.withValues(alpha: 0.12)
                            : const Color(0xFFFCE7F3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: isSelected
                            ? colors.primary
                            : const Color(0xFFDB2777),
                      ),
                    ),
                    title: Text(
                      reciter.displayName(settings.languageCode),
                      style: GoogleFonts.notoSansThai(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? colors.primary : colors.textStrong,
                      ),
                    ),
                    subtitle: Text(
                      reciter.style,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: colors.primary,
                          )
                        : null,
                    onTap: () {
                      settings.setReciterId(reciter.id);
                      mushafAudio.setReciterId(reciter.id);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Bottom Sheet: Hifz & Bluetooth Devices ─────────────────────────────────
  void _showHifzDevicesSheet(
    BuildContext context,
    AppThemeColors colors,
    bool isThai,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.borderSoft,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isThai
                            ? 'อุปกรณ์ฮิฟซ์ & รีโมทเปลี่ยนหน้า'
                            : 'Hifz Remote & BLE Devices',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: colors.textStrong,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Expanded(
                    child: BleDeviceManagementUI(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Bottom Sheet: About ────────────────────────────────────────────────────
  void _showAboutSheet(
    BuildContext context,
    AppThemeColors colors,
    bool isThai,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Thai Quran: อัลกุรอานแปลไทย',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.textStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0 (quran-th.com)',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isThai
                      ? 'แอปพลิเคชันอัลกุรอานแปลไทยเพื่อพี่น้องมุสลิมไทย มุ่งเน้นการอ่านที่สงบ สะอาด สบายตา ไม่มีโฆษณารบกวน พร้อมระบบเป้าหมายการอ่าน ตะดับบุร และความหมายคำต่อคำ'
                      : 'Thai Quran app designed for calm, ad-free reflection and memorization with word-by-word analysis and reading journeys.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    color: colors.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                  onPressed: () {
                    launchUrl(
                      Uri.parse('https://quran-th.com'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text(
                    isThai ? 'เยี่ยมชมเว็บไซต์ quran-th.com' : 'Visit quran-th.com',
                    style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Bottom Sheet: Auth Modal (Sign In / Register) ──────────────────────────
  void _showAuthBottomSheet(
    BuildContext context,
    bool isThai,
    AppThemeColors colors,
  ) {
    AuthBottomSheet.show(context);
  }

  // ── Dialog: Edit Display Name ──────────────────────────────────────────────
  void _showEditDisplayNameDialog(
    BuildContext context,
    SupabaseProvider supabaseProv,
    AppThemeColors colors,
    bool isThai,
  ) {
    final controller = TextEditingController(
      text: supabaseProv.displayName,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(color: colors.borderSoft),
        ),
        title: Text(
          isThai ? 'แก้ไขชื่อที่แสดง' : 'Edit Display Name',
          style: GoogleFonts.notoSansThai(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: colors.textStrong,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.notoSansThai(color: colors.textStrong),
          decoration: InputDecoration(
            hintText: isThai ? 'ใส่ชื่อของคุณ' : 'Enter your name',
            filled: true,
            fillColor: colors.surfaceMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: BorderSide(color: colors.borderSoft),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isThai ? 'ยกเลิก' : 'Cancel',
              style: GoogleFonts.notoSansThai(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await supabaseProv.updateDisplayName(newName);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              }
            },
            child: Text(
              isThai ? 'บันทึก' : 'Save',
              style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reveal List Tile Component ───────────────────────────────────────────────
class _RevealListTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _RevealListTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colors = settings.getAppColors();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // Pastel square icon badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Title & Current value subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? const Color(0xFFDC2626)
                          : colors.textStrong,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        color: isDestructive
                            ? const Color(0xFFEF4444)
                            : colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Trailing element
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDestructive
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF9CA3AF),
              ),
          ],
        ),
      ),
    );
  }
}

