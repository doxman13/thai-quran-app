import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';
import '../providers/supabase_provider.dart';
import '../services/guest_lifecycle_service.dart';
import '../theme/app_theme.dart';

const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.5 24c0-1.61-.15-3.16-.41-4.69H24v9h12.75c-.55 2.81-2.13 5.19-4.5 6.78l7 5.44C43.34 36.36 46.5 30.73 46.5 24z"/>
  <path fill="#FBBC05" d="M10.54 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.98-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7-5.44c-2.47 1.66-5.63 2.75-8.89 2.75-6.26 0-11.57-4.22-13.46-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

const String _appleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 170 170">
  <path fill="#FFFFFF" d="M150.37 130.25c-2.45 5.66-5.35 10.87-8.71 15.66-4.58 6.53-8.33 11.05-11.22 13.56-4.48 4.12-9.28 6.23-14.42 6.35-3.69 0-8.14-1.05-13.32-3.18-5.19-2.12-9.97-3.17-14.34-3.17-4.58 0-9.49 1.05-14.75 3.17-5.26 2.13-9.5 3.24-12.74 3.35-4.35.13-9.16-1.9-14.42-6.08-3.7-3.04-7.58-7.7-11.64-13.98-5.34-8.25-9.61-17.77-12.79-28.56-3.18-10.79-4.78-21.28-4.78-31.47 0-14.57 3.59-26.68 10.77-36.32 7.18-9.64 16.32-14.58 27.42-14.82 5.01 0 10.63 1.25 16.86 3.75 6.23 2.5 10.3 3.86 12.22 4.08 1.92-.22 6.13-1.63 12.63-4.23 6.5-2.6 12.18-3.79 17.04-3.58 13.06.66 23.36 4.99 30.9 12.98-11.74 7.08-17.47 16.89-17.18 29.43.3 9.94 4.15 18.23 11.55 24.87 3.7 3.37 7.93 5.87 12.7 7.5-2.39 6.84-5.2 13.82-8.43 20.94zm-37.49-106.1c0 7.39-2.67 14.28-8.01 20.67-6.2 7.39-13.78 11.63-22.74 12.72-.22-1.3-.33-2.4-.33-3.26 0-7.39 2.83-14.57 8.48-21.52 2.83-3.48 6.36-6.31 10.6-8.48 4.24-2.18 8.16-3.37 11.76-3.59.11 1.19.24 2.34.24 3.46z"/>
</svg>
''';

/// Unified Auth Bottom Sheet for Google, Apple, and Email authentication.
class AuthBottomSheet {
  static Future<void> show(
    BuildContext context, {
    String? customTitle,
    String? customSubtitle,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final colors = settings.getAppColors();
    final isThai = settings.languageCode == 'th';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AuthBottomSheetContent(
        colors: colors,
        isThai: isThai,
        customTitle: customTitle,
        customSubtitle: customSubtitle,
      ),
    );
  }
}

/// Warning dialog presented to Guest (non-login) users when bookmarking.
class GuestBookmarkWarningDialog {
  /// Checks whether warning should be displayed; if so, displays dialog.
  /// Returns `true` if the bookmark operation should proceed, or `false` if cancelled.
  static Future<bool> checkAndPrompt(BuildContext context) async {
    final shouldPrompt =
        await GuestLifecycleService.shouldPromptGuestBookmarkWarning();
    if (!shouldPrompt) {
      await GuestLifecycleService.touchGuestActivity();
      return true;
    }

    if (!context.mounted) return false;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final colors = settings.getAppColors();
    final isThai = settings.languageCode == 'th';

    bool dontRemindAgain = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                side: BorderSide(color: colors.borderSoft),
              ),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bookmark_outline_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isThai
                          ? 'บุ๊กมาร์กชั่วคราว (30 วัน)'
                          : 'Guest Bookmark (30 Days)',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textStrong,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isThai
                        ? 'คุณกำลังใช้งานในฐานะผู้ใช้ทั่วไป (ไม่ได้เข้าสู่ระบบ)\n\nข้อมูลที่คั่นหน้านี้จะถูกเก็บไว้เฉพาะในเครื่องนี้เท่านั้น และจะถูกล้างอัตโนมัติหากไม่ได้เปิดใช้งานเกิน 30 วัน\n\nเข้าสู่ระบบเพื่อสำรองข้อมูลและเก็บไว้อย่างถาวรบนคลาวด์'
                        : 'You are using the app as a guest.\n\nThis bookmark will be stored locally on this device only and will be cleared automatically if inactive for over 30 days.\n\nSign in to back up and preserve your bookmarks permanently in the cloud.',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 13,
                      color: colors.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      setDialogState(() {
                        dontRemindAgain = !dontRemindAgain;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: dontRemindAgain,
                          activeColor: colors.primary,
                          onChanged: (val) {
                            setDialogState(() {
                              dontRemindAgain = val ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            isThai
                                ? 'ไม่ต้องเตือนอีกในครั้งถัดไป'
                                : "Don't remind me again",
                            style: GoogleFonts.notoSansThai(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx, false);
                    AuthBottomSheet.show(context);
                  },
                  child: Text(
                    isThai ? 'เข้าสู่ระบบ (Sign In)' : 'Sign In',
                    style: GoogleFonts.notoSansThai(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
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
                  onPressed: () {
                    Navigator.pop(ctx, true);
                  },
                  child: Text(
                    isThai ? 'บันทึกลงเครื่องต่อไป' : 'Save as Guest',
                    style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      if (dontRemindAgain) {
        await GuestLifecycleService.setSuppressGuestBookmarkWarning(true);
      }
      await GuestLifecycleService.touchGuestActivity();
      return true;
    }

    return false;
  }
}

/// Dialog displayed when a feature (like Notes or Goals) requires Cloud Login.
class AuthRequiredDialog {
  static Future<bool> show(
    BuildContext context, {
    required String featureName,
    required String reason,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final colors = settings.getAppColors();
    final isThai = settings.languageCode == 'th';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: BorderSide(color: colors.borderSoft),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isThai ? 'เข้าสู่ระบบเพื่อใช้งาน' : 'Sign in Required',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textStrong,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            reason,
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
                isThai ? 'ไว้คราวหลัง' : 'Later',
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
              onPressed: () {
                Navigator.pop(ctx, true);
                AuthBottomSheet.show(context);
              },
              child: Text(
                isThai ? 'เข้าสู่ระบบ (Sign In)' : 'Sign In',
                style: GoogleFonts.notoSansThai(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

/// Content inside the AuthBottomSheet.
class AuthBottomSheetContent extends StatefulWidget {
  final AppThemeColors colors;
  final bool isThai;
  final String? customTitle;
  final String? customSubtitle;

  const AuthBottomSheetContent({
    super.key,
    required this.colors,
    required this.isThai,
    this.customTitle,
    this.customSubtitle,
  });

  @override
  State<AuthBottomSheetContent> createState() => _AuthBottomSheetContentState();
}

class _AuthBottomSheetContentState extends State<AuthBottomSheetContent> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth(SupabaseProvider supabaseProv) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = widget.isThai
            ? 'กรุณากรอกอีเมลและรหัสผ่าน'
            : 'Please enter email and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await supabaseProv.signUp(
          email,
          password,
          _nameController.text.trim(),
        );
      } else {
        await supabaseProv.signInWithPassword(email, password);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseProv = Provider.of<SupabaseProvider>(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
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
                    color: widget.colors.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.customTitle ??
                    (_isSignUp
                        ? (widget.isThai ? 'สร้างบัญชีใหม่' : 'Create Account')
                        : (widget.isThai
                            ? 'เข้าสู่ระบบคลาวด์'
                            : 'Sign In to Cloud')),
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansThai(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: widget.colors.textStrong,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.customSubtitle ??
                    (widget.isThai
                        ? 'สำรองข้อมูลบุ๊กมาร์ก บันทึก และเป้าหมายการอ่านของคุณอย่างปลอดภัย'
                        : 'Sync bookmarks, reflections, and reading goals permanently'),
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansThai(
                  fontSize: 12,
                  color: widget.colors.textMuted,
                ),
              ),
              const SizedBox(height: 18),

              // OAuth Buttons
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  side: BorderSide(color: widget.colors.borderSoft),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                icon: SvgPicture.string(_googleLogoSvg, width: 18, height: 18),
                label: Text(
                  widget.isThai ? 'เข้าสู่ระบบด้วย Google' : 'Sign in with Google',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.colors.textStrong,
                  ),
                ),
                onPressed: () async {
                  try {
                    await supabaseProv.signInWithGoogle();
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() => _errorMessage = '$e');
                  }
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  backgroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                icon: SvgPicture.string(_appleLogoSvg, width: 18, height: 18),
                label: Text(
                  widget.isThai ? 'เข้าสู่ระบบด้วย Apple' : 'Sign in with Apple',
                  style: GoogleFonts.notoSansThai(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                onPressed: () async {
                  try {
                    await supabaseProv.signInWithApple();
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() => _errorMessage = '$e');
                  }
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Divider(color: widget.colors.borderSoft),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      widget.isThai ? 'หรือใช้อีเมล' : 'Or with Email',
                      style: GoogleFonts.notoSansThai(
                        fontSize: 12,
                        color: widget.colors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: widget.colors.borderSoft),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.notoSansThai(
                      fontSize: 12,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],

              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: widget.isThai ? 'ชื่อของคุณ' : 'Your Name',
                    filled: true,
                    fillColor: widget.colors.surfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: BorderSide(color: widget.colors.borderSoft),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: widget.isThai ? 'อีเมล' : 'Email',
                  filled: true,
                  fillColor: widget.colors.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    borderSide: BorderSide(color: widget.colors.borderSoft),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: widget.isThai ? 'รหัสผ่าน' : 'Password',
                  filled: true,
                  fillColor: widget.colors.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    borderSide: BorderSide(color: widget.colors.borderSoft),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                onPressed: _isLoading ? null : () => _handleEmailAuth(supabaseProv),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isSignUp
                            ? (widget.isThai ? 'สมัครสมาชิก' : 'Sign Up')
                            : (widget.isThai ? 'เข้าสู่ระบบ' : 'Sign In'),
                        style: GoogleFonts.notoSansThai(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 10),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                    _errorMessage = null;
                  });
                },
                child: Text(
                  _isSignUp
                      ? (widget.isThai
                          ? 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'
                          : 'Already have an account? Sign In')
                      : (widget.isThai
                          ? 'ยังไม่มีบัญชี? สมัครสมาชิก'
                          : "Don't have an account? Sign Up"),
                  style: GoogleFonts.notoSansThai(
                    fontSize: 13,
                    color: widget.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final uri = Uri.parse('https://quran-th.com/privacy');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text(
                    widget.isThai
                        ? 'นโยบายความเป็นส่วนตัว (Privacy Policy)'
                        : 'Privacy Policy',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 11.5,
                      color: widget.colors.textMuted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
