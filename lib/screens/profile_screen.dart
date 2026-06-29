// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/supabase_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/local_reading_provider.dart';
import '../providers/mushaf_reading_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/stats_provider.dart';
import '../data/quran_repository.dart';
import 'bookmarks_screen.dart';
import 'notes_screen.dart';
import 'reading_screen.dart';
import 'tadabbur_private_screen.dart';

class ProfileScreen extends StatefulWidget {
  final QuranRepository? repository;

  const ProfileScreen({Key? key, this.repository}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _otpSent = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _successMessage;
  Future<List<Map<String, dynamic>>>? _reportsFuture;
  String? _fetchedUserId;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showEditNameDialog(
    BuildContext context,
    SupabaseProvider supabaseProv,
  ) {
    final controller = TextEditingController(text: supabaseProv.displayName);
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final primaryColor = settings.getPrimaryColor();

        return AlertDialog(
          title: const Text('แก้ไขชื่อ (Edit Name)'),
          content: Form(
            key: dialogFormKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'ชื่อ (Name)',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'กรุณากรอกชื่อ';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก (Cancel)'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!dialogFormKey.currentState!.validate()) return;
                try {
                  await supabaseProv.updateDisplayName(controller.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'อัปเดตชื่อสำเร็จ (Name updated successfully)',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                    );
                  }
                }
              },
              child: const Text('บันทึก (Save)'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSendOtp(SupabaseProvider supabaseProv) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await supabaseProv.signInWithOtp(_emailController.text);
      setState(() {
        _otpSent = true;
        _successMessage =
            'Magic link and verification code sent to your email!';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVerifyOtp(SupabaseProvider supabaseProv) async {
    if (_otpController.text.trim().length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await supabaseProv.verifyOtp(_emailController.text, _otpController.text);
      setState(() {
        _successMessage = 'Successfully logged in!';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
        _otpSent = false;
        _emailController.clear();
        _otpController.clear();
        _successMessage = 'Logged out successfully.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleManualSync(
    SupabaseProvider supabaseProv,
    LocalReadingProvider readingProv,
    MushafReadingProvider mushafProv,
    NotesProvider notesProv,
  ) async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await readingProv.syncBookmarksAndProfilesWithSupabase(
        supabaseProv.userId,
      );
      await readingProv.syncReadingStateWithSupabase(supabaseProv.userId);
      await mushafProv.syncWithSupabase(supabaseProv.userId);
      await notesProv.syncWithSupabase();
      if (mounted) {
        setState(() {
          _successMessage =
              'ซิงค์ข้อมูลสำเร็จแล้ว (Sync completed successfully!)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'เกิดข้อผิดพลาดในการซิงค์: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _openReading(String surahId, String verseId) {
    final repository = widget.repository;
    if (repository == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repository: repository,
          initialSurah: surahId,
          initialVerseId: verseId,
        ),
      ),
    );
  }

  Future<void> _openBookmarks() async {
    final repository = widget.repository;
    if (repository == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookmarksScreen(repository: repository),
      ),
    );
    if (!mounted || result == null) return;

    _openReading(
      result['surahId'].toString(),
      result['verseId']?.toString() ??
          ((result['verseIndex'] as int? ?? 0) + 1).toString(),
    );
  }

  void _openNotes() {
    final repository = widget.repository;
    if (repository == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotesScreen(repository: repository)),
    );
  }

  void _openTadabbur() {
    final repository = widget.repository;
    if (repository == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TadabburPrivateScreen(repository: repository),
      ),
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

    if (supabaseProv.isLoggedIn &&
        (_reportsFuture == null || _fetchedUserId != supabaseProv.userId)) {
      _fetchedUserId = supabaseProv.userId;
      _reportsFuture = _fetchUserReports(supabaseProv.userId);
    }

    final primaryColor = settings.getPrimaryColor();
    final isDark = settings.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์ผู้อ่าน (Reader Profile)'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              if (!supabaseProv.isLoggedIn) ...[
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: primaryColor.withOpacity(0.2),
                          child: Icon(Icons.person, color: primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ผู้อ่านทั่วไป (Guest Reader)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                supabaseProv.displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _showEditNameDialog(context, supabaseProv),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Auth form
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.cloud_sync, size: 64, color: primaryColor),
                          const SizedBox(height: 16),
                          Text(
                            'ซิงค์ข้อมูลกับคลาวด์',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.teal.shade900,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'เข้าสู่ระบบเพื่อสำรองข้อมูลและซิงค์การตั้งค่า บุ๊กมาร์ก และบันทึกต่าง ๆ ไปยังเว็บและอุปกรณ์อื่น ๆ',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          if (!_otpSent) ...[
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'อีเมล (Email)',
                                prefixIcon: const Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty)
                                  return 'กรุณากรอกอีเมล';
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(val.trim())) {
                                  return 'รูปแบบอีเมลไม่ถูกต้อง';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () => _handleSendOtp(supabaseProv),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'ขอรหัสเข้าสู่ระบบ (Send OTP)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ] else ...[
                            Text(
                              'รหัสยืนยัน 6 หลักถูกส่งไปยัง ${_emailController.text} แล้ว',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: 'รหัสยืนยัน 6 หลัก (OTP Code)',
                                prefixIcon: const Icon(Icons.lock_open),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                counterText: "",
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () => _handleVerifyOtp(supabaseProv),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'ยืนยันรหัส (Verify Code)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _otpSent = false;
                                        _otpController.clear();
                                      });
                                    },
                              child: const Text('เปลี่ยนอีเมล (Change Email)'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Logged in UI
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: primaryColor.withOpacity(0.2),
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              supabaseProv.displayName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () =>
                                  _showEditNameDialog(context, supabaseProv),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          supabaseProv.userEmail,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _isSyncing
                                ? null
                                : () => _handleManualSync(
                                    supabaseProv,
                                    readingProv,
                                    mushafProv,
                                    notesProv,
                                  ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _isSyncing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.green,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.sync,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isSyncing
                                        ? 'กำลังซิงค์ (Syncing...)'
                                        : 'ซิงค์กับคลาวด์แล้ว (Tap to Sync)',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Statistics Header
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'สถิติการอ่านของคุณ (Your Reading Stats)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Statistics Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.4,
                          children: [
                            _buildStatCard(
                              icon: Icons.menu_book,
                              title: 'แผนการอ่าน',
                              value: '${readingProv.activeProfiles.length} / 5',
                              color: Colors.blue,
                              onTap: () => Navigator.pop(context),
                            ),
                            _buildStatCard(
                              icon: Icons.bookmark,
                              title: 'บุ๊กมาร์ก',
                              value: '${readingProv.bookmarks.length}',
                              color: Colors.orange,
                              onTap: _openBookmarks,
                            ),
                            _buildStatCard(
                              icon: Icons.note_alt,
                              title: 'บันทึกส่วนตัว',
                              value: '${notesProv.personalNotes.length}',
                              color: Colors.purple,
                              onTap: _openNotes,
                            ),
                            _buildStatCard(
                              icon: Icons.favorite_rounded,
                              title: 'Favorites & Notes',
                              value: '${notesProv.personalNotes.length}',
                              color: Colors.red,
                              onTap: _openTadabbur,
                            ),
                            _buildStatCard(
                              icon: Icons.local_fire_department,
                              title: 'วันอ่านต่อเนื่อง',
                              value: '${statsProv.streakCount} วัน',
                              color: Colors.red,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Mushaf Reading',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.import_contacts_rounded,
                                title: 'Profiles',
                                value:
                                    '${mushafProv.activeCustomProfiles.length}',
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.bookmark_added_outlined,
                                title: 'Page bookmarks',
                                value: '${mushafProv.pageBookmarks.length}',
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.format_quote_rounded,
                                title: 'Verse bookmarks',
                                value: '${mushafProv.verseBookmarks.length}',
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.history_rounded,
                                title: 'Recent pages',
                                value: '${mushafProv.recentReadings.length}',
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                        if (readingProv.archivedProfiles.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'แผนการอ่านที่เก็บถาวร (Archived Plans)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...readingProv.archivedProfiles.map((profile) {
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.blueGrey.shade800.withOpacity(
                                          0.5,
                                        )
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.archive_outlined,
                                  color: primaryColor,
                                ),
                                title: Text(
                                  profile.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () => readingProv
                                          .restoreProfile(profile.id),
                                      child: const Text('Restore'),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('ลบแผนการอ่าน?'),
                                            content: Text(
                                              'คุณต้องการลบ "${profile.name}" หรือไม่? การกระทำนี้ไม่สามารถย้อนกลับได้',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('ยกเลิก'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  readingProv.deleteProfile(
                                                    profile.id,
                                                  );
                                                  Navigator.pop(context);
                                                },
                                                child: const Text(
                                                  'ลบ',
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        if (readingProv.recentReadings.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Recent Readings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...readingProv.recentReadings.take(5).map((reading) {
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading: Icon(
                                  Icons.history,
                                  color: primaryColor,
                                ),
                                title: Text(
                                  '${reading.verse.surahId}:${reading.verse.verseId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: const Text('Continue from this ayah'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openReading(
                                  reading.verse.surahId,
                                  reading.verse.verseId,
                                ),
                              ),
                            );
                          }),
                        ],

                        _buildReportsSection(supabaseProv),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () => _handleSignOut(supabaseProv),
                          icon: const Icon(Icons.logout),
                          label: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'ออกจากระบบ (Sign Out)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
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
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
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

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'reviewed_fixed':
        bgColor = Colors.green.withOpacity(0.15);
        textColor = Colors.green.shade800;
        label = 'แก้ไขแล้ว (Fixed)';
        break;
      case 'reviewed_not_needed':
        bgColor = Colors.grey.withOpacity(0.15);
        textColor = Colors.grey.shade700;
        label = 'ไม่ต้องแก้ไข (No Action)';
        break;
      case 'pending_review':
      default:
        bgColor = Colors.amber.withOpacity(0.15);
        textColor = Colors.amber.shade900;
        label = 'รอดำเนินการ (Pending)';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.prompt(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildReportsSection(SupabaseProvider supabaseProv) {
    if (!supabaseProv.isLoggedIn) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'รายงานข้อผิดพลาด (My Error Reports)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    setState(() {
                      _reportsFuture = _fetchUserReports(supabaseProv.userId);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _reportsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'เกิดข้อผิดพลาดในการโหลดข้อมูล (Error loading reports)',
                    style: GoogleFonts.prompt(color: Colors.redAccent),
                  );
                }
                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'ไม่มีประวัติการรายงานข้อผิดพลาด (No error reports submitted yet)',
                      style: GoogleFonts.prompt(
                        color: Colors.grey.shade500,
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
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final surahId = report['surah_id']?.toString() ?? '';
                    final ayahNum = report['ayah_number']?.toString() ?? '';
                    final reportedText =
                        report['reported_verse_text']?.toString() ?? '';
                    final userComment =
                        report['user_comment']?.toString() ?? '';
                    final status =
                        report['status']?.toString() ?? 'pending_review';
                    final adminNotes =
                        report['admin_resolution_notes']?.toString() ?? '';
                    final dateStr = report['created_at']?.toString() ?? '';

                    DateTime? parsedDate;
                    String formattedDate = '';
                    if (dateStr.isNotEmpty) {
                      try {
                        parsedDate = DateTime.parse(dateStr).toLocal();
                        formattedDate =
                            '${parsedDate.day}/${parsedDate.month}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';
                      } catch (_) {}
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => _openReading(surahId, ayahNum),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'อายะฮ์ $surahId:$ayahNum',
                                        style: GoogleFonts.prompt(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.open_in_new,
                                        size: 12,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                          if (formattedDate.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'ข้อความโองการที่รายงาน (Verse text):',
                            style: GoogleFonts.prompt(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Text(
                            reportedText,
                            softWrap: true,
                            style: GoogleFonts.prompt(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ความคิดเห็นของคุณ (Your comment):',
                            style: GoogleFonts.prompt(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Text(
                            userComment,
                            softWrap: true,
                            style: GoogleFonts.prompt(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (adminNotes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.admin_panel_settings,
                                        size: 16,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'บันทึกจากผู้ดูแล (Admin Note):',
                                        style: GoogleFonts.prompt(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    adminNotes,
                                    softWrap: true,
                                    style: GoogleFonts.prompt(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey.shade200
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
