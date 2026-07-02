import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../data/quran_repository.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WelcomeScreen extends StatefulWidget {
  final QuranRepository repository;

  const WelcomeScreen({Key? key, required this.repository}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  Timer? _timeoutTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 3), () {
      _completeWelcome();
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _completeWelcome() async {
    if (_navigated) return;
    _navigated = true;
    _timeoutTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(repository: widget.repository),
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
                color: primaryColor.withOpacity(0.08),
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
                color: accentColor.withOpacity(0.08),
              ),
            ),
          ),

          SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    
                    // Bismillah SVG
                    SvgPicture.asset(
                      'assets/Bismillah_Calligraphy6.svg',
                      width: 240,
                      colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
                    ),
                    const SizedBox(height: 24),
                    
                    // Translation
                    Text(
                      'ด้วยพระนามของอัลลอฮฺ\nผู้ทรงกรุณาปรานี ผู้ทรงเมตตาเสมอ',
                      style: GoogleFonts.prompt(
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
                    ),
                    const SizedBox(height: 8),
                    
                    // App Name
                    Text(
                      'อ่านอัลกุรอาน',
                      style: GoogleFonts.prompt(
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
