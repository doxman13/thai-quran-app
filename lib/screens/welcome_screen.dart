import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../data/quran_repository.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF607465); // Sage theme primary
    final accentColor = const Color(0xFF9AA58F);

    return Scaffold(
      body: Stack(
        children: [
          // Elegant subtle gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF151711),
                          const Color(0xFF1E241E),
                          const Color(0xFF0F110D),
                        ]
                      : [
                          const Color(0xFFF3F5EF),
                          const Color(0xFFF8F7F2),
                          const Color(0xFFE6EAE0),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Column(
                children: [
                  const Spacer(),
                  
                  // App Icon / Logo Container with glassmorphism glow
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 64,
                      backgroundColor: isDark ? const Color(0xFF1D1F19) : Colors.white,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/icons/playstore-icon.png',
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.menu_book,
                              size: 48,
                              color: primaryColor,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // App Title
                  Text(
                    'อัลกุรอานพร้อมแปลไทย',
                    style: GoogleFonts.prompt(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF262C25),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    'Thai Quran Reader',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Value propositions / features list
                  _buildFeatureRow(
                    context,
                    icon: Icons.chrome_reader_mode_outlined,
                    title: 'อ่านง่าย สบายตา',
                    description: 'ฟอนต์อุษมานีย์สวยงาม ปรับขนาดตัวอักษรและสีธีมได้ตามชอบ',
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(
                    context,
                    icon: Icons.sync,
                    title: 'ระบบบันทึกความจำและจดโน้ต',
                    description: 'บันทึกความคืบหน้าแบบออฟไลน์ พร้อมฟังก์ชันบันทึกตดับบุร (Tadabbur)',
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(
                    context,
                    icon: Icons.check_circle_outline,
                    title: 'ตรวจสอบและเปรียบเทียบภาษา',
                    description: 'แปลไทยฉบับปรับปรุง (V3) คู่กับภาษาอังกฤษและฉบับเดิม',
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  
                  const Spacer(),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _completeWelcome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'เริ่มต้นใช้งาน',
                            style: GoogleFonts.prompt(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    'v1.0.0 • salamthailand.com',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.prompt(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF262C25),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.prompt(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
