// ═══════════════════════════════════════════════════════════════
//  Result Screen (§3.8)
//
//  Most important screen. Layout explicitly follows the spec.
//  NO "Expert Review" screen. NO "ML (SVM/LR)".
//  Threshold displays 0.385, model v10.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/scan_result.dart';
import '../widgets/aperture_view.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import 'cam_screen.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final File imageFile;
  final ScanResult result;
  final bool lowConfidence;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.result,
    this.lowConfidence = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _saved = false;

  Future<void> _save() async {
    if (_saved) return;
    try {
      await DatabaseService.instance.saveScan(
        userId: AuthService.instance.currentUserId,
        imageFile: widget.imageFile,
        result: widget.result,
        bodySite: 'Unknown', // Could be added via a dialog
        lowConfidence: widget.lowConfidence,
      );
      if (mounted) {
        setState(() => _saved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan saved to history')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  void _viewCam() {
    if (widget.result.camMap == null) return;
    Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => CamScreen(
          imageFile: widget.imageFile,
          camMap: widget.result.camMap!,
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    try {
      await PdfService.instance.exportScan(
        imageFile: widget.imageFile,
        result: widget.result,
        scanId: 'SG-Export', // In real app, fetch actual ID from DB after save
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskName = widget.result.risk.name;

    return Scaffold(
      backgroundColor: AppTheme.film,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          children: [
            // 1. Aperture with scanned image
            Center(
              child: ApertureView(
                size: 180,
                image: FileImage(widget.imageFile),
                showRing: true,
              ),
            ),
            const SizedBox(height: 32),

            // 2. Risk Display (Color + Word + Glyph)
            Text(
              '${riskName.riskGlyph} ${riskName.riskLabel}',
              style: AppTheme.body(size: 16, weight: FontWeight.w600, color: riskName.riskColor),
            ),
            const SizedBox(height: 8),
            
            // 3. Archivo, large, risk-coloured percentage
            Text(
              widget.result.melanomaPercent,
              style: AppTheme.display(size: 64, color: riskName.riskColor),
            ),
            
            // 4. Mono label
            Text(
              'MELANOMA RISK',
              style: AppTheme.mono(size: 14, color: AppTheme.slate),
            ),
            const SizedBox(height: 6),
            Text(
              'Validated on dermoscopy images. For phone photos, see cancer risk below.',
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 12, color: AppTheme.slateSoft),
            ),
            const SizedBox(height: 24),

            // 5. Recommendation text
            Text(
              widget.result.recommendation,
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 15, height: 1.5),
            ),
            if (widget.result.melanomaProb < 0.10 && widget.result.cancerProb < 0.20 && widget.result.gateValidProb < 0.95) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.aperture.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No distinct lesion features detected. If you were scanning a specific mole, retake with it centred in the frame.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(size: 13, height: 1.4, color: AppTheme.apertureLt),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // 6. Metrics block (IBM Plex Mono)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.line),
                  bottom: BorderSide(color: AppTheme.line),
                ),
              ),
              child: Column(
                children: [
                  _metricRow('Melanoma risk', widget.result.melanomaPercent),
                  const SizedBox(height: 8),
                  _metricRow('Cancer risk', widget.result.cancerPercent),
                  const SizedBox(height: 8),
                  _metricRow('Threshold', '0.385'),
                  const SizedBox(height: 8),
                  _metricRow('Model', 'v10'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 7. Actions
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _viewCam,
                child: const Text('View region of interest'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saved ? null : _save,
                    child: Text(_saved ? 'Saved' : 'Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _exportPdf,
                    child: const Text('Export PDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // 8. Footer disclaimer
            Text(
              'Screening aid only. Not a diagnosis.',
              style: AppTheme.body(size: 12, color: AppTheme.slateSoft),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.mono(size: 14, color: AppTheme.slate)),
        Text(value, style: AppTheme.mono(size: 14, weight: FontWeight.w500)),
      ],
    );
  }
}
