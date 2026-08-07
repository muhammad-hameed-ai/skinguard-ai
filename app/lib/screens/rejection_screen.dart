// ═══════════════════════════════════════════════════════════════
//  Rejection Screen (§3.6)
//
//  Three variants: not_lesion, blurry, wound.
//  Shows which check failed with the actual number.
//  "Use anyway" option for blur marks the record as low-confidence.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/scan_result.dart';
import '../services/preprocessing.dart';
import 'result_screen.dart';

class RejectionScreen extends StatelessWidget {
  final File imageFile;
  final ScanResult result;
  
  // Note: Since QualityResult isn't returned directly by InferenceService in the 
  // current model (it just returns GateVerdict.qualityFail), we calculate it here
  // again if needed, or we use dummy values for now. 
  // For production, InferenceService should pass the QualityResult back.
  // We'll re-run the fast quality check here just to display the numbers.

  const RejectionScreen({
    super.key,
    required this.imageFile,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (result.verdict == GateVerdict.qualityFail) {
      return _buildQualityRejection(context);
    } else if (result.verdict == GateVerdict.wound) {
      return _buildWoundRejection(context);
    } else {
      return _buildNotLesionRejection(context);
    }
  }

  Widget _buildWrapper(BuildContext context, String title, Widget content, List<Widget> actions) {
    return Scaffold(
      backgroundColor: AppTheme.film,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Scan Rejected'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.error_outline, size: 64, color: AppTheme.refer),
              const SizedBox(height: 24),
              Text(title, 
                style: AppTheme.display(size: 24, color: AppTheme.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              content,
              
              const Spacer(),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityRejection(BuildContext context) {
    return FutureBuilder<QualityResult?>(
      // Re-run quality check to get the exact numbers
      future: _runQualityCheck(),
      builder: (context, snapshot) {
        final q = snapshot.data;
        final lap = q?.laplacianVariance ?? 0.0;
        
        return _buildWrapper(
          context,
          'Photo is too blurry',
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sharpness', style: AppTheme.body(size: 16)),
                    Text('${lap.toStringAsFixed(1)} / 100', style: AppTheme.mono(size: 16, weight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: (lap.clamp(0, 100)).toInt(),
                      child: Container(height: 12, color: AppTheme.refer),
                    ),
                    Expanded(
                      flex: (100 - lap.clamp(0, 100)).toInt(),
                      child: Container(height: 12, color: AppTheme.film),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Minimum 12.0 required', style: AppTheme.mono(size: 12, color: AppTheme.slateSoft)),
              ],
            ),
          ),
          [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retake'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                // "Use anyway" marks the record as low-confidence
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(
                      imageFile: imageFile, 
                      result: result,
                      lowConfidence: true,
                    )
                  )
                );
              },
              child: const Text('Use anyway'),
            ),
          ]
        );
      }
    );
  }

  Widget _buildNotLesionRejection(BuildContext context) {
    return _buildWrapper(
      context,
      'No skin lesion found',
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          children: [
            _buildCheckRow('Resolution', 'PASS'),
            const Divider(height: 24, color: AppTheme.line),
            _buildCheckRow('Sharpness', 'PASS'),
            const Divider(height: 24, color: AppTheme.line),
            _buildCheckRow('Lighting', 'PASS'),
            const Divider(height: 24, color: AppTheme.line),
            _buildCheckRow('Skin detected', '${(result.gateValidProb * 100).toStringAsFixed(1)}%', isFail: true),
          ],
        ),
      ),
      [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Take another photo'),
        ),
      ]
    );
  }

  Widget _buildWoundRejection(BuildContext context) {
    return _buildWrapper(
      context,
      'This looks like a wound',
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line),
        ),
        child: Text(
          'SkinGuard only assesses moles and pigmented lesions.\n\n'
          'If a wound is not healing, see a doctor regardless.',
          style: AppTheme.body(size: 16, height: 1.5),
        ),
      ),
      [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Scan a different area'),
        ),
      ]
    );
  }

  Widget _buildCheckRow(String label, String value, {bool isFail = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.body(size: 15, color: AppTheme.slate)),
        Text(value, style: AppTheme.mono(size: 15, color: isFail ? AppTheme.refer : AppTheme.clear, weight: FontWeight.w500)),
      ],
    );
  }

  Future<QualityResult?> _runQualityCheck() async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = decodeImage(bytes);
      if (decoded != null) {
        return qualityCheck(decoded);
      }
    } catch (e) {
      // ignore
    }
    return null;
  }
}
