// ═══════════════════════════════════════════════════════════════
//  Login Screen (§3.3)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aperture_view.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final err = await AuthService.instance.login(
      _usernameCtrl.text, _passwordCtrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
    } else {
      _goHome();
    }
  }

  Future<void> _guest() async {
    setState(() => _loading = true);
    await AuthService.instance.continueAsGuest();
    if (!mounted) return;
    _goHome();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.film,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Center(child: ApertureView(size: 80, showRing: true)),
              const SizedBox(height: 24),
              Center(
                child: Text('Welcome Back',
                    style: AppTheme.display(size: 24)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Sign in to access your scan history',
                    style: AppTheme.body(color: AppTheme.slate)),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: AppTheme.body(size: 13, color: AppTheme.refer)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Sign In'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loading ? null : () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()));
                },
                child: const Text('Create Account'),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _guest,
                  child: Text('Continue as Guest',
                      style: AppTheme.body(
                          color: AppTheme.aperture,
                          weight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'All data stays on this device',
                  style: AppTheme.body(size: 12, color: AppTheme.slateSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
