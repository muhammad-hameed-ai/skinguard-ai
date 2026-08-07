// ═══════════════════════════════════════════════════════════════
//  Onboarding — 3 pages + disclaimer (§3.2)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/aperture_view.dart';
import 'auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingPage(
      icon: Icons.health_and_safety,
      title: 'Early Skin Cancer\nScreening',
      subtitle: 'AI-powered lesion analysis running entirely on your device. '
          'No internet required. No data ever leaves your phone.',
    ),
    _OnboardingPage(
      icon: Icons.auto_awesome,
      title: 'How It Works',
      subtitle: 'Capture  →  Analyse  →  Result\n\n'
          'Take a photo of a skin lesion. The AI analyses shape, colour '
          'and pattern, then provides a risk assessment in seconds.',
    ),
    _OnboardingPage(
      icon: Icons.medical_information,
      title: 'Medical Disclaimer',
      subtitle: 'SkinGuard AI is an experimental screening tool, '
          'NOT a diagnostic medical device.\n\n'
          'The risk percentages are estimates from an AI model and may '
          'produce false positives or false negatives.\n\n'
          'Never ignore professional medical advice. Always consult '
          'a dermatologist for medical concerns.',
      isDisclaimer: true,
    ),
  ];

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.film,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => Container(
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentPage == i
                          ? AppTheme.aperture
                          : AppTheme.line,
                    ),
                  ),
                ),
              ),
            ),
            // Action button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: _currentPage == _pages.length - 1
                    ? FilledButton(
                        onPressed: _complete,
                        child: const Text('I Understand & Continue'),
                      )
                    : FilledButton(
                        onPressed: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: const Text('Next'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDisclaimer;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isDisclaimer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isDisclaimer)
            ApertureView(size: 120, showRing: true)
          else
            Icon(icon, size: 72, color: AppTheme.signal),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.display(size: 26, weight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          if (isDisclaimer)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.line),
              ),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTheme.body(size: 14, color: AppTheme.slate, height: 1.6),
              ),
            )
          else
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 15, color: AppTheme.slate, height: 1.6),
            ),
        ],
      ),
    );
  }
}
