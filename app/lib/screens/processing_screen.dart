// ═══════════════════════════════════════════════════════════════
//  Processing Screen (§3.7)
//
//  Rotating ring around the aperture. Plain-language stage list.
//  Footer: "No data leaves this phone."
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/aperture_view.dart';
import '../services/inference_service.dart';
import '../services/preprocessing.dart';
import '../models/scan_result.dart';
import 'result_screen.dart';
import 'rejection_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final File imageFile;
  const ProcessingScreen({super.key, required this.imageFile});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinCtrl;
  int _stage = 0;
  String? _error;

  final _stages = const [
    'Checking image quality',
    'Confirming this is a lesion',
    'Analysing shape and colour',
    'Cross-checking models',
    'Measuring confidence',
  ];

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      // Stage 0: Quality check
      setState(() => _stage = 0);
      await Future.delayed(const Duration(milliseconds: 300));

      // Stage 1: Gate
      setState(() => _stage = 1);
      await Future.delayed(const Duration(milliseconds: 200));

      // Ensure models are ready
      if (!InferenceService.instance.isInitialized) {
        try {
          await InferenceService.instance.initialize();
        } catch (e, st) {
          debugPrint('Model init failed: $e\n$st');
          throw AppException(
            'The analysis models could not be loaded.\n'
            'Please reinstall the app.'
          );
        }
      }

      // Stage 2: Analyse
      setState(() => _stage = 2);

      final result = await InferenceService.instance.analyze(widget.imageFile);

      // Debug: print raw logits to verify the cancer model runs independently each time
      debugPrint('═══ INFERENCE DEBUG ═══');
      debugPrint('  melanomaRaw (logit): ${result.melanomaRaw}');
      debugPrint('  melanomaProb:        ${result.melanomaProb}');
      debugPrint('  cancerRaw (logit):   ${result.cancerRaw}');
      debugPrint('  cancerProb:          ${result.cancerProb}');
      debugPrint('  gateValidProb:       ${result.gateValidProb}');
      debugPrint('══════════════════════');

      // Stage 3-4
      setState(() => _stage = 3);
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _stage = 4);
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Navigate to result or rejection
      if (!result.wasAccepted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RejectionScreen(
              imageFile: widget.imageFile,
              result: result,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              imageFile: widget.imageFile,
              result: result,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.film,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Rotating ring around aperture
                AnimatedBuilder(
                  animation: _spinCtrl,
                  builder: (_, child) => Transform.rotate(
                    angle: _spinCtrl.value * 6.28,
                    child: child,
                  ),
                  child: ApertureView(
                    size: 140,
                    image: FileImage(widget.imageFile),
                    showRing: true,
                  ),
                ),

                const SizedBox(height: 40),

                // Stage list
                ...List.generate(_stages.length, (i) {
                  String icon;
                  Color color;
                  if (i < _stage) {
                    icon = '✓';
                    color = AppTheme.clear;
                  } else if (i == _stage) {
                    icon = '◐';
                    color = AppTheme.aperture;
                  } else {
                    icon = '○';
                    color = AppTheme.slateSoft;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(icon, style: TextStyle(
                            fontSize: 16, color: color)),
                        const SizedBox(width: 12),
                        Text(_stages[i],
                            style: AppTheme.body(
                                size: 15,
                                color: color,
                                weight: i == _stage
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ],
                    ),
                  );
                }),

                if (_error != null) ...[
                  const SizedBox(height: 24),
                  Text('Error: $_error',
                      style: AppTheme.body(color: AppTheme.refer, size: 13)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],

                const Spacer(),
                Text('No data leaves this phone.',
                    style: AppTheme.body(
                        size: 12, color: AppTheme.slateSoft)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}
