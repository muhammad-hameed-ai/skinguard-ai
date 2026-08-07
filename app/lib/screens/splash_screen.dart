// ═══════════════════════════════════════════════════════════════
//  Splash Screen (§3.1)
//
//  Dark ink background, aperture as logo.
//  Pre-warms models during display (min 2.5s).
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/aperture_view.dart';
import '../services/inference_service.dart';
import 'onboarding_screen.dart';
import 'auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    _loadAndNavigate();
  }

  Future<void> _loadAndNavigate() async {
    final start = DateTime.now();

    // Preload Google Fonts so nothing shifts on first paint
    GoogleFonts.archivo();
    GoogleFonts.inter();
    GoogleFonts.ibmPlexMono();

    // Kick off model initialization in the background so the app opens instantly.
    // The ProcessingScreen will wait for this to finish if the user scans immediately.
    InferenceService.instance.initialize().then((_) {
      InferenceService.instance.warmUp().catchError((e) {
        debugPrint('Splash warmup error: $e');
      });
    }).catchError((e) {
      debugPrint('Splash init error: $e');
    });

    // Ensure minimum 1.2s display for the animation
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    if (elapsed < 1200) {
      await Future.delayed(Duration(milliseconds: 1200 - elapsed));
    }

    if (!mounted) return;

    // Check if onboarding was completed
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('onboarding_complete') ?? false;

    // Check if user has a session
    final hasSession = await AuthService.instance.restoreSession();

    if (!mounted) return;

    Widget destination;
    if (!onboarded) {
      destination = const OnboardingScreen();
    } else if (!hasSession) {
      destination = const LoginScreen();
    } else {
      destination = const HomeScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ApertureView(size: 140, showRing: true),
              const SizedBox(height: 32),
              Text(
                'SkinGuard AI',
                style: AppTheme.display(
                  size: 28, weight: FontWeight.w800, color: AppTheme.paper),
              ),
              const SizedBox(height: 8),
              Text(
                'Offline AI Skin Cancer Screening',
                style: AppTheme.body(
                  size: 14, color: AppTheme.slateSoft),
              ),
              const SizedBox(height: 40),

              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.apertureLt,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
