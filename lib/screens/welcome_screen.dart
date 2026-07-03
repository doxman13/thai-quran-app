import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../data/quran_repository.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../shared/shared.dart';

class WelcomeScreen extends StatefulWidget {
  final QuranRepository repository;

  const WelcomeScreen({super.key, required this.repository});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _minimumWelcomeDuration = Duration(milliseconds: 4200);

  Timer? _fallbackTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _prepareHome();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _prepareHome() async {
    _fallbackTimer = Timer(const Duration(seconds: 8), () {
      _completeWelcome(repositoryReady: false);
    });

    var repositoryReady = false;
    await Future.wait([
      Future<void>.delayed(_minimumWelcomeDuration),
      widget.repository
          .init()
          .then((_) {
            repositoryReady = true;
          })
          .catchError((_) {
            repositoryReady = false;
          }),
    ]);

    await _completeWelcome(repositoryReady: repositoryReady);
  }

  Future<void> _completeWelcome({required bool repositoryReady}) async {
    if (_navigated) return;
    _navigated = true;
    _fallbackTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 520),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: HomeScreen(
                  repository: widget.repository,
                  repositoryReady: repositoryReady,
                ),
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final primaryColor = colorScheme.primary;
    final accentColor = colorScheme.secondary;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Elegant subtle gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surfaceContainerLow,
                    colorScheme.surface,
                    colorScheme.surfaceContainerLow,
                  ],
                ),
              ),
            ),
          ),

          // Subtle graphic elements in background
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: 24.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Bismillah SVG
                    SvgPicture.asset(
                      'assets/Bismillah_Calligraphy6.svg',
                      width: 240,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Translation
                    Text(
                      context.tr('welcome_bismillah'),
                      style: GoogleFonts.notoSansThai(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const Spacer(),

                    // Logo at the bottom
                    Image.asset(
                      'assets/icons/mipmap-xxxhdpi/ic_launcher_foreground.png',
                      height: 96,
                      color: isDark ? Colors.white : null,
                    ),
                    const SizedBox(height: 8),

                    // App Name
                    Text(
                      context.tr('welcome_app_name'),
                      style: GoogleFonts.notoSansThai(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
