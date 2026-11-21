import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/quran_repository.dart';
import '../services/remote_content_service.dart';
import 'home_screen.dart';

/// Full-bleed branded welcome splash matching `assets/quran-th-logo-clean.svg`.
class WelcomeSplashCanvas extends StatelessWidget {
  const WelcomeSplashCanvas({super.key});

  /// Exact background fill color of `assets/quran-th-logo-clean.svg` (`.cls-2`).
  static const Color brandBackground = Color(0xFF0E5C59);
  static const Color _creamAccent = Color(0xFFF4ECDB);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final logoSize = (shortest * 0.64).clamp(180.0, 300.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: brandBackground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: const Alignment(0, -0.05),
              child: Semantics(
                label: 'quran-th.com',
                image: true,
                child: SvgPicture.asset(
                  'assets/quran-th-logo-clean.svg',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _creamAccent.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  final QuranRepository repository;
  final Duration minimumDuration;

  const WelcomeScreen({
    super.key,
    required this.repository,
    this.minimumDuration = const Duration(milliseconds: 2200),
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  Timer? _holdTimer;
  bool _minElapsed = false;
  bool _repoDone = false;
  bool _repoReady = false;
  bool _showHome = false;

  @override
  void initState() {
    super.initState();
    unawaited(_syncInBackground());
    _startWarmupAndHold();
  }

  void _startWarmupAndHold() {
    if (widget.minimumDuration <= Duration.zero) {
      _minElapsed = true;
    } else {
      _holdTimer = Timer(widget.minimumDuration, () {
        _minElapsed = true;
        _tryTransition();
      });
    }

    unawaited(_initRepository());
  }

  Future<void> _initRepository() async {
    try {
      await widget.repository.init();
      _repoReady = true;
    } catch (error) {
      debugPrint('Unable to initialize Quran repository on welcome: $error');
      _repoReady = false;
    } finally {
      _repoDone = true;
      _tryTransition();
    }
  }

  void _tryTransition() {
    if (!mounted || _showHome || !_minElapsed || !_repoDone) return;
    setState(() {
      _showHome = true;
    });
  }

  Future<void> _syncInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome', true);
    } catch (error) {
      debugPrint('Unable to persist welcome state: $error');
    }

    try {
      await RemoteContentService.instance.updateAllIfDue();
    } catch (error) {
      debugPrint('Unable to auto-check Quran content updates: $error');
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _showHome
          ? HomeScreen(
              key: const ValueKey('home_ready'),
              repository: widget.repository,
              repositoryReady: _repoReady,
            )
          : const WelcomeSplashCanvas(key: ValueKey('welcome_splash')),
    );
  }
}
