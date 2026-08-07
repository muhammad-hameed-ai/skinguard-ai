// ═══════════════════════════════════════════════════════════════
//  Signup Screen (§3.3)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signup() async {
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final err = await AuthService.instance.createAccount(
      username: _usernameCtrl.text,
      password: _passwordCtrl.text,
      fullName: _nameCtrl.text,
      securityQuestion: _questionCtrl.text.isNotEmpty
          ? _questionCtrl.text : null,
      securityAnswer: _answerCtrl.text.isNotEmpty
          ? _answerCtrl.text : null,
    );

    if (!mounted) return;

    if (err != null) {
      setState(() { _loading = false; _error = err; });
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.film,
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
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
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.filmSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Password Recovery',
                        style: AppTheme.body(weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'This app works offline. If you forget your password, '
                      'it cannot be reset from a server. Set a security '
                      'question to recover your account.',
                      style: AppTheme.body(
                          size: 12, color: AppTheme.slate, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _questionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Security Question (optional)',
                        hintText: 'e.g. What is your pet\'s name?',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _answerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Answer',
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: AppTheme.body(size: 13, color: AppTheme.refer)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _signup,
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
