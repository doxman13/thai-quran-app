// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/supabase_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/stats_provider.dart';
import '../models/tadabbur_note.dart';
import '../data/quran_repository.dart';
import '../data/quran_foundation_repository.dart';
import '../data/offline_surah_names.dart';
import '../data/medina_mushaf_pages.dart';
import 'bookmarks_screen.dart';
import 'reading_screen.dart';
import 'mushaf_reader_screen.dart';
import 'tadabbur_private_screen.dart';
import 'tadabbur_community_screen.dart';
import '../theme/app_theme.dart';
import '../shared/shared.dart';

const String googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.5 24c0-1.61-.15-3.16-.41-4.69H24v9h12.75c-.55 2.81-2.13 5.19-4.5 6.78l7 5.44C43.34 36.36 46.5 30.73 46.5 24z"/>
  <path fill="#FBBC05" d="M10.54 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.98-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7-5.44c-2.47 1.66-5.63 2.75-8.89 2.75-6.26 0-11.57-4.22-13.46-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

class ProfileScreen extends StatefulWidget {
  final QuranRepository? repository;
  final bool isEmbedded;
  final VoidCallback? onOpenGoalsTab;

  const ProfileScreen({
    super.key,
    this.repository,
    this.isEmbedded = false,
    this.onOpenGoalsTab,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _foundationRepository = QuranFoundationRepository();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _successMessage;
  Future<List<Map<String, dynamic>>>? _reportsFuture;
  String? _fetchedUserId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showEditNameDialog(
    BuildContext context,
    SupabaseProvider supabaseProv,
    AppThemeColors colors,
  ) {
    final controller = TextEditingController(text: supabaseProv.displayName);
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: BorderSide(color: colors.borderSoft, width: 1),
          ),
          title: Text(
            context.tr('edit_name'),
            style: GoogleFonts.notoSansThai(
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          content: Form(
            key: dialogFormKey,
            child: TextFormField(
              controller: controller,
              style: GoogleFonts.notoSansThai(color: colors.foreground),
              decoration: InputDecoration(
                labelText: context.tr('name'),
                labelStyle: GoogleFonts.notoSansThai(color: colors.textMuted),
                filled: true,
                fillColor: colors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  borderSide: BorderSide(color: colors.borderSoft),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  borderSide: BorderSide(color: colors.borderSoft),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return context.tr('please_enter_name');
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.tr('cancel'),
                style: GoogleFonts.notoSansThai(
                  color: colors.textMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                if (!dialogFormKey.currentState!.validate()) return;
                try {
                  await supabaseProv.updateDisplayName(controller.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('name_updated_successfully')),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.tr('error_occurred', args: {'error': '$e'}),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(
                context.tr('save'),
                style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePasswordSignIn(SupabaseProvider supabaseProv) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await supabaseProv.signInWithPassword(
        _emailController.text,
        _passwordController.text,
      );
      setState(() {
        _successMessage = context.tr('login_success');
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordSignUp(SupabaseProvider supabaseProv) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await supabaseProv.signUp(
        _emailController.text,
        _passwordController.text,
        _nameController.text,
      );
      setState(() {
        _successMessage = context.tr('register_success');
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut(SupabaseProvider supabaseProv) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await supabaseProv.signOut();
      setState(() {
        _isSignUp = false;
        _emailController.clear();
        _passwordController.clear();
        _nameController.clear();
        _successMessage = context.tr('logout_success');
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn(SupabaseProvider supabaseProv) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await supabaseProv.signInWithGoogle();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleManualSync(
    SupabaseProvider supabaseProv,
    SettingsProvider settingsProv,
    LocalReadingProvider readingProv,
    MushafReadingProvider mushafProv,
    NotesProvider notesProv,
    StatsProvider statsProv,
  ) async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await readingProv.flushPendingProfileSyncs();
      await readingProv.flushPendingRecentReadingSync();
      await readingProv.flushPendingReadingStateSync();
      final mushafProfilesFlushed = await mushafProv.flushPendingProfileSyncs();
      if (!mushafProfilesFlushed) {
        throw StateError('Mushaf profile changes are still pending sync.');
      }
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
      if (mounted) {
        setState(() {
          _successMessage = 'ซิงค์ข้อมูลกับคลาวด์สำเร็จเรียบร้อย';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'เกิดข้อผิดพลาดในการซิงค์: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _openReading(String surahId, String verseId) async {
    final repository = widget.repository ?? QuranRepository();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repository: repository,
          initialSurah: surahId,
          initialVerseId: verseId,
        ),
      ),
    );
    if (!mounted || result is! Map) return;
    final resultSurahId = result['surahId']?.toString();
    final resultVerseId = result['verseId']?.toString();
    if (resultSurahId != null && resultVerseId != null) {
      final localReading = context.read<LocalReadingProvider>();
      final resultProfileId = result['profileId']?.toString();
      var profile = resultProfileId != null
          ? localReading.profileById(resultProfileId)
          : localReading.activeProfile;

      if (profile != null && isShortcutProfile(profile)) {
        if (resultSurahId != profile.start.surahId) {
          profile = null;
        }
      }

      await localReading.addRecentReading(
        verse: toVerseRef(resultSurahId, resultVerseId),
        profileId: profile?.id,
      );
    }
  }

  void _openMushaf(String surahId, String verseId) {
    final sId = int.tryParse(surahId) ?? 1;
    final vId = int.tryParse(verseId) ?? 1;
    final pageNumber = getMedinaMushafPageNumber(sId, vId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafReaderScreen(
          quranRepository: widget.repository ?? QuranRepository(),
          foundationRepository: _foundationRepository,
          initialPage: pageNumber,
          initialHighlightVerseKey: '$sId:$vId',
        ),
      ),
    );
  }

  Future<void> _openBookmarks({int initialTab = 0}) async {
    final repository = widget.repository ?? QuranRepository();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookmarksScreen(
          repository: repository,
          initialTab: initialTab,
        ),
      ),
    );
    if (!mounted || result == null) return;

    _openReading(
      result['surahId'].toString(),
      result['verseId']?.toString() ??
          ((result['verseIndex'] as int? ?? 0) + 1).toString(),
    );
  }

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

    if (supabaseProv.isLoggedIn &&
        (_reportsFuture == null || _fetchedUserId != supabaseProv.userId)) {
      _fetchedUserId = supabaseProv.userId;
      _reportsFuture = _fetchUserReports(supabaseProv.userId);
    }

    final latestReading = readingProv.recentReadings.isNotEmpty
        ? readingProv.recentReadings.first
        : null;

    final notesList = notesProv.personalNotes.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final publicNotesCount = notesList.where((n) => n.isPublic).length;
    final privateNotesCount = notesList.length - publicNotesCount;
    final activeErrorMessage = _errorMessage ?? supabaseProv.authError;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: colors.background,
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    size: 24,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'พื้นที่ผู้ใช้งาน',
                    style: GoogleFonts.notoSansThai(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colors.foreground,
                    ),
                  ),
                ],
              ),
              foregroundColor: colors.foreground,
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Error / Success Notice ──────────────────────────────────────
            if (activeErrorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: const Color(0xFFF98080)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Color(0xFFC81E1E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeErrorMessage,
                        style: GoogleFonts.notoSansThai(
                          color: const Color(0xFFC81E1E),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2EE),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: const Color(0xFFB7D4C7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF0E5A4A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: GoogleFonts.notoSansThai(
                          color: const Color(0xFF0E5A4A),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── 1. USER IDENTITY CARD ───────────────────────────────────────
            _buildUserIdentityCard(
              colors,
              supabaseProv,
              settings,
              readingProv,
              mushafProv,
              notesProv,
              statsProv,
            ),
            const SizedBox(height: 16),

            // ── 2. RESUME READING HERO BANNER ────────────────────────────────
            if (latestReading != null)
              _buildResumeReadingBanner(colors, latestReading),

            // ── 3. 6 INTERACTIVE STAT PILLS ──────────────────────────────────
            const SizedBox(height: 16),
            _buildStatsGrid(
              colors,
              statsProv,
              readingProv,
              mushafProv,
              notesProv,
              supabaseProv,
              isThai,
            ),
            const SizedBox(height: 20),

            // ── 4. QUICK LIBRARY SHORTCUTS ───────────────────────────────────
            _buildQuickLibraryShortcuts(
              colors,
              readingProv,
              mushafProv,
              notesProv,
              isThai,
            ),
            const SizedBox(height: 20),

            // ── 5. RECENT READINGS & REFLECTIONS PREVIEW ─────────────────────
            _buildRecentAndReflectionsSection(
              colors,
              readingProv,
              notesList,
              publicNotesCount,
              privateNotesCount,
              isThai,
            ),

            // ── 6. PROBLEM REPORTS (Logged in) ───────────────────────────────
            if (supabaseProv.isLoggedIn) ...[
              const SizedBox(height: 20),
              _buildReportsSection(supabaseProv, colors, isThai),
            ],

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildUserIdentityCard(
    AppThemeColors colors,
    SupabaseProvider supabaseProv,
    SettingsProvider settings,
    LocalReadingProvider readingProv,
    MushafReadingProvider mushafProv,
    NotesProvider notesProv,
    StatsProvider statsProv,
  ) {
    final isLoggedIn = supabaseProv.isLoggedIn;
    final displayName = supabaseProv.displayName;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName.substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isLoggedIn
                            ? const Color(0xFFEAF2EE)
                            : colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLoggedIn
                              ? const Color(0xFFB7D4C7)
                              : colors.borderSoft,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLoggedIn ? Icons.cloud_done : Icons.smartphone,
                            size: 11,
                            color: isLoggedIn
                                ? const Color(0xFF0E5A4A)
                                : colors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isLoggedIn
                                ? 'บัญชีคลาวด์ quran-th.com'
                                : 'โหมดอ่านในเครื่อง (Local Mode)',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isLoggedIn
                                  ? const Color(0xFF0E5A4A)
                                  : colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName
                                : 'ผู้อ่านนิรนาม (Guest Reader)',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: colors.foreground,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () =>
                              _showEditNameDialog(context, supabaseProv, colors),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isLoggedIn
                          ? supabaseProv.userEmail
                          : 'ข้อมูลถูกบันทึกในเครื่องนี้อย่างปลอดภัย',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.borderSoft),
          const SizedBox(height: 14),

          // Actions
          if (isLoggedIn)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing
                        ? null
                        : () => _handleManualSync(
                              supabaseProv,
                              settings,
                              readingProv,
                              mushafProv,
                              notesProv,
                              statsProv,
                            ),
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 15),
                    label: Text(
                      _isSyncing ? 'กำลังซิงค์...' : 'ซิงค์ข้อมูล',
                      style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.borderSoft),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _handleSignOut(supabaseProv),
                  icon: const Icon(Icons.logout, size: 15),
                  label: Text(
                    'ออกจากระบบ',
                    style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC81E1E),
                    backgroundColor: const Color(0xFFFDE8E8),
                    side: const BorderSide(color: Color(0xFFF98080)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            )
          else
            _buildGuestAuthSection(colors, supabaseProv),
        ],
      ),
    );
  }

  Widget _buildGuestAuthSection(
    AppThemeColors colors,
    SupabaseProvider supabaseProv,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'ซิงค์ที่คั่นหน้า บันทึก และเป้าหมายการอ่านของคุณข้ามอุปกรณ์ด้วยบัญชี quran-th.com',
            style: GoogleFonts.notoSansThai(
              fontSize: 12,
              color: colors.textMuted,
              height: 1.4,
            ),
          ),
        ),
        // Google Sign In Button (Strict Editorial Standard - No gradients, no fuzzy shadows)
        InkWell(
          onTap: (_isLoading || supabaseProv.isSigningIn)
              ? null
              : () => _handleGoogleSignIn(supabaseProv),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading || supabaseProv.isSigningIn) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'กำลังเชื่อมต่อกับ Google...',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                ] else ...[
                  SvgPicture.string(googleLogoSvg, width: 18, height: 18),
                  const SizedBox(width: 10),
                  Text(
                    'ลงชื่อเข้าใช้ด้วย Google',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(child: Divider(color: colors.borderSoft)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'หรือใช้อีเมล',
                style: GoogleFonts.notoSansThai(
                  fontSize: 11,
                  color: colors.textMuted,
                ),
              ),
            ),
            Expanded(child: Divider(color: colors.borderSoft)),
          ],
        ),
        const SizedBox(height: 12),

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSignUp) ...[
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.notoSansThai(color: colors.foreground, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'ชื่อที่แสดง',
                    labelStyle: GoogleFonts.notoSansThai(color: colors.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: colors.surfaceMuted,
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.borderSoft),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.borderSoft),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'กรุณาระบุชื่อที่แสดง';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.notoSansThai(color: colors.foreground, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'อีเมล',
                  labelStyle: GoogleFonts.notoSansThai(color: colors.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: colors.surfaceMuted,
                  prefixIcon: const Icon(Icons.email_outlined, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'กรุณาระบุอีเมล';
                  if (!val.contains('@')) return 'รูปแบบอีเมลไม่ถูกต้อง';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: GoogleFonts.notoSansThai(color: colors.foreground, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  labelStyle: GoogleFonts.notoSansThai(color: colors.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: colors.surfaceMuted,
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: colors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'กรุณาระบุรหัสผ่าน';
                  if (val.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_isSignUp) {
                          _handlePasswordSignUp(supabaseProv);
                        } else {
                          _handlePasswordSignIn(supabaseProv);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isSignUp ? 'สมัครสมาชิก' : 'เข้าสู่ระบบด้วยอีเมล',
                        style: GoogleFonts.notoSansThai(fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 8),

              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp ? 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ' : 'ยังไม่มีบัญชี? สมัครสมาชิกที่นี่',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResumeReadingBanner(
    AppThemeColors colors,
    dynamic latestReading,
  ) {
    final surahId = latestReading.verse.surahId as String;
    final verseId = latestReading.verse.verseId as String;
    final repository = widget.repository ?? QuranRepository();
    final surahName = repository.getSurahName(surahId).replaceAll(RegExp(r'^\d+\.\s*'), '');
    final surahAr = offlineSurahNamesAr[surahId];

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border(
          left: BorderSide(color: colors.primary, width: 3.5),
          top: BorderSide(color: colors.borderSoft),
          right: BorderSide(color: colors.borderSoft),
          bottom: BorderSide(color: colors.borderSoft),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2EE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Icon(Icons.bookmark, size: 15, color: Color(0xFF0E5A4A)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'อ่านต่อจากจุดเดิม',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              Text(
                timeago.format(latestReading.readAt),
                style: GoogleFonts.notoSansThai(
                  fontSize: 11,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$surahName • อายะฮฺที่ $verseId',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.foreground,
                      ),
                    ),
                    if (surahAr != null)
                      Text(
                        surahAr,
                        style: const TextStyle(
                          fontFamily: 'UthmanicHafs',
                          fontSize: 16,
                          color: Color(0xFF0E5A4A),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openReading(surahId, verseId),
                    icon: const Icon(Icons.translate, size: 13),
                    label: Text(
                      'อ่านฉบับแปล',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openMushaf(surahId, verseId),
                    icon: const Icon(Icons.menu_book, size: 13),
                    label: Text(
                      'มุศหัฟ',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8A6530),
                      backgroundColor: const Color(0xFFF6EFE3),
                      side: const BorderSide(color: Color(0xFFE8DFC8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    AppThemeColors colors,
    StatsProvider statsProv,
    LocalReadingProvider readingProv,
    MushafReadingProvider mushafProv,
    NotesProvider notesProv,
    SupabaseProvider supabaseProv,
    bool isThai,
  ) {
    final bookmarksCount = readingProv.bookmarks.length +
        mushafProv.pageBookmarks.length +
        mushafProv.verseBookmarks.length;
    final reflectionsCount = notesProv.personalNotes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isThai ? 'สถิติการอ่านและคลังของฉัน' : 'READING ACTIVITY & LIBRARY',
          style: GoogleFonts.notoSansThai(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _buildStatCard(
              colors: colors,
              icon: Icons.local_fire_department,
              iconColor: const Color(0xFFD97706),
              iconBgColor: const Color(0xFFFEF3C7),
              title: isThai ? 'อ่านต่อเนื่อง' : 'Reading Streak',
              value: '${statsProv.streakCount} ${isThai ? 'วัน' : 'Days'}',
              onTap: widget.onOpenGoalsTab,
            ),
            _buildStatCard(
              colors: colors,
              icon: Icons.today,
              iconColor: colors.primary,
              iconBgColor: const Color(0xFFEAF2EE),
              title: isThai ? 'อ่านวันนี้' : 'Read Today',
              value: '${statsProv.todayReadCount} ${isThai ? 'อายะฮฺ' : 'Ayat'}',
              onTap: widget.onOpenGoalsTab,
            ),
            _buildStatCard(
              colors: colors,
              icon: Icons.date_range,
              iconColor: const Color(0xFF0E5A4A),
              iconBgColor: const Color(0xFFEAF2EE),
              title: isThai ? '7 วันล่าสุด' : 'This Week',
              value: '${statsProv.weekReadCount} ${isThai ? 'อายะฮฺ' : 'Ayat'}',
              onTap: widget.onOpenGoalsTab,
            ),
            _buildStatCard(
              colors: colors,
              icon: Icons.bookmark,
              iconColor: const Color(0xFF8A6530),
              iconBgColor: const Color(0xFFF6EFE3),
              title: isThai ? 'บุ๊กมาร์กทั้งหมด' : 'Bookmarks',
              value: '$bookmarksCount ${isThai ? 'รายการ' : 'Saved'}',
              onTap: () => _openBookmarks(initialTab: 1),
            ),
            _buildStatCard(
              colors: colors,
              icon: Icons.note_alt_outlined,
              iconColor: const Color(0xFF0E5A4A),
              iconBgColor: const Color(0xFFEAF2EE),
              title: isThai ? 'บันทึกตดับบุร' : 'Reflections',
              value: '$reflectionsCount ${isThai ? 'บันทึก' : 'Notes'}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TadabburPrivateScreen(
                      repository: widget.repository ?? QuranRepository(),
                    ),
                  ),
                );
              },
            ),
            _buildStatCard(
              colors: colors,
              icon: Icons.flag_outlined,
              iconColor: colors.primary,
              iconBgColor: const Color(0xFFEAF2EE),
              title: isThai ? 'เป้าหมายที่กำลังอ่าน' : 'Active Goals',
              value:
                  '${readingProv.activeProfiles.where((p) => !isFreeReadProfile(p)).length + mushafProv.activeCustomProfiles.length}',
              onTap: widget.onOpenGoalsTab,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required AppThemeColors colors,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: colors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 11,
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: GoogleFonts.notoSansThai(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLibraryShortcuts(
    AppThemeColors colors,
    LocalReadingProvider readingProv,
    MushafReadingProvider mushafProv,
    NotesProvider notesProv,
    bool isThai,
  ) {
    final recentCount = readingProv.recentReadings.length + mushafProv.recentReadings.length;
    final bookmarkCount = readingProv.bookmarks.length +
        mushafProv.pageBookmarks.length +
        mushafProv.verseBookmarks.length;
    final favCount = notesProv.personalNotes.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isThai ? 'คลังส่วนตัวของฉัน' : 'My Saved Library',
            style: GoogleFonts.notoSansThai(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildLibraryButton(
                  colors: colors,
                  label: isThai ? 'อ่านล่าสุด ($recentCount)' : 'Recent ($recentCount)',
                  icon: Icons.history,
                  onTap: () => _openBookmarks(initialTab: 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLibraryButton(
                  colors: colors,
                  label: isThai ? 'บุ๊กมาร์ก ($bookmarkCount)' : 'Bookmarks ($bookmarkCount)',
                  icon: Icons.bookmark_border,
                  onTap: () => _openBookmarks(initialTab: 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLibraryButton(
                  colors: colors,
                  label: isThai ? 'บันทึก ($favCount)' : 'Notes ($favCount)',
                  icon: Icons.favorite_border,
                  onTap: () => _openBookmarks(initialTab: 2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryButton({
    required AppThemeColors colors,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.borderSoft),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: colors.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.notoSansThai(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAndReflectionsSection(
    AppThemeColors colors,
    LocalReadingProvider readingProv,
    List<TadabburNote> notesList,
    int publicCount,
    int privateNotesCount,
    bool isThai,
  ) {
    final recentList = readingProv.recentReadings.take(4).toList();
    final repository = widget.repository ?? QuranRepository();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Recent Readings Card ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: colors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        isThai ? 'ประวัติการอ่านล่าสุด' : 'Recent Readings',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _openBookmarks(initialTab: 0),
                    child: Text(
                      isThai ? 'ดูทั้งหมด' : 'View all',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (recentList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      isThai ? 'ยังไม่มีประวัติการอ่าน' : 'No recent reading history.',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                )
              else
                ...recentList.map((reading) {
                  final surahName = repository
                      .getSurahName(reading.verse.surahId)
                      .replaceAll(RegExp(r'^\d+\.\s*'), '');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () => _openReading(
                        reading.verse.surahId,
                        reading.verse.verseId,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.borderSoft),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$surahName (${reading.verse.surahId}:${reading.verse.verseId})',
                              style: GoogleFonts.notoSansThai(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colors.foreground,
                              ),
                            ),
                            Text(
                              timeago.format(reading.readAt),
                              style: GoogleFonts.notoSansThai(
                                fontSize: 10,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── My Tadabbur Reflections Breakdown ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: colors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note, size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        isThai ? 'บันทึกตดับบุรของฉัน' : 'My Reflections',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TadabburPrivateScreen(
                            repository: repository,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      isThai ? 'ดูทั้งหมด' : 'View all',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Counter Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.borderSoft),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'เฉพาะฉัน',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 10,
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$privateNotesCount',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2EE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFB7D4C7)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'แชร์สู่ชุมชน',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 10,
                              color: const Color(0xFF0E5A4A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$publicCount',
                            style: GoogleFonts.notoSansThai(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0E5A4A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Reflections Snippet List
              if (notesList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      isThai ? 'ยังไม่มีบันทึกตดับบุร' : 'No reflections written yet.',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                )
              else
                ...notesList.take(3).map((note) {
                  final surahName = repository
                      .getSurahName(note.surahId)
                      .replaceAll(RegExp(r'^\d+\.\s*'), '');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () => _openReading(note.surahId, note.verseId),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.borderSoft),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$surahName ${note.surahId}:${note.verseId}',
                                  style: GoogleFonts.notoSansThai(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                                Icon(
                                  note.isPublic ? Icons.public : Icons.lock_outline,
                                  size: 12,
                                  color: colors.textMuted,
                                ),
                              ],
                            ),
                            if (note.noteText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                note.noteText,
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 12,
                                  color: colors.foreground,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TadabburPrivateScreen(
                              repository: repository,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.note_alt_outlined, size: 14),
                      label: Text(
                        'บันทึกส่วนตัว',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.borderSoft),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TadabburCommunityScreen(
                              repository: repository,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.public, size: 14),
                      label: Text(
                        'ชุมชนตดับบุร',
                        style: GoogleFonts.notoSansThai(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.foreground,
                        side: BorderSide(color: colors.borderSoft),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUserReports(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('error_reports')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching user reports: $e');
      return [];
    }
  }

  Widget _buildStatusBadge(String status, AppThemeColors colors) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'reviewed_fixed':
        bgColor = const Color(0xFFEAF2EE);
        textColor = const Color(0xFF0E5A4A);
        label = 'แก้ไขแล้ว';
        break;
      case 'reviewed_not_needed':
        bgColor = colors.surfaceMuted;
        textColor = colors.textMuted;
        label = 'ไม่ต้องแก้ไข';
        break;
      case 'pending_review':
      default:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        label = 'รอดำเนินการ';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSansThai(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildReportsSection(
    SupabaseProvider supabaseProv,
    AppThemeColors colors,
    bool isThai,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: colors.borderSoft),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.report_problem_outlined, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    isThai ? 'รายงานปัญหาข้อผิดพลาด' : 'My Problem Reports',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 16, color: colors.primary),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    _reportsFuture = _fetchUserReports(supabaseProv.userId);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _reportsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  ),
                );
              }
              final reports = snapshot.data ?? [];
              if (reports.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    isThai
                        ? 'ไม่มีประวัติการรายงานข้อผิดพลาด'
                        : 'No error reports submitted yet',
                    style: GoogleFonts.notoSansThai(
                      color: colors.textMuted,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reports.length,
                separatorBuilder: (context, index) =>
                    Divider(color: colors.borderSoft, height: 16),
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final surahId = report['surah_id']?.toString() ?? '';
                  final ayahNum = report['ayah_number']?.toString() ?? '';
                  final userComment = report['user_comment']?.toString() ?? '';
                  final status = report['status']?.toString() ?? 'pending_review';
                  final dateStr = report['created_at']?.toString() ?? '';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => _openReading(surahId, ayahNum),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2EE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'อายะฮฺ $surahId:$ayahNum',
                                style: GoogleFonts.notoSansThai(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0E5A4A),
                                ),
                              ),
                            ),
                          ),
                          _buildStatusBadge(status, colors),
                        ],
                      ),
                      if (userComment.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          userComment,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 12,
                            color: colors.foreground,
                          ),
                        ),
                      ],
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateStr.split('T').first,
                          style: GoogleFonts.notoSansThai(
                            fontSize: 10,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
