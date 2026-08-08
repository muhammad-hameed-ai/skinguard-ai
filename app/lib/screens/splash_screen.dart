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

  late DateTime _startTime;
  static const _minSplash = Duration(milliseconds: 2200);
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    try {
      GoogleFonts.archivo();
      GoogleFonts.inter();
      GoogleFonts.ibmPlexMono();

      await InferenceService.instance.initialize();
      await InferenceService.instance.warmUp();
    } catch (e, s) {
      debugPrint('Startup failed: $e\n$s');
      if (mounted) setState(() => _error = 'Startup failed. Please reinstall.');
      return;
    }

    final elapsed = DateTime.now().difference(_startTime);
    final remaining = _minSplash - elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);

    if (!mounted) return;
    _navigateOnward();
  }

  Future<void> _navigateOnward() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('onboarding_complete') ?? false;
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

              if (_error != null)
                Text(
                  _error!,
                  style: AppTheme.body(size: 14, color: AppTheme.refer),
                  textAlign: TextAlign.center,
                )
              else
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
