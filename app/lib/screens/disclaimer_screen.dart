import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  Future<void> _accept(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disclaimer_accepted', true);
    
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.medical_information, size: 72, color: Color(0xFF0B6E63)),
              const SizedBox(height: 32),
              Text(
                "Medical Disclaimer",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0B6E63),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  "SkinGuard AI is an experimental screening tool, NOT a diagnostic medical device.\n\n"
                  "The risk percentages provided are estimates from an AI model and may produce false positives or false negatives.\n\n"
                  "Never ignore professional medical advice because of something you read here. Always consult a dermatologist for medical concerns.",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _accept(context),
                child: const Text("I Understand and Agree"),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
