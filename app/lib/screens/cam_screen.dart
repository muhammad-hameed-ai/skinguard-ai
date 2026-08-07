// ═══════════════════════════════════════════════════════════════
//  CAM Screen (§3.9)
//
//  Full-screen CAM overlay at 0.45 opacity with adjustable slider.
//  Caption verbatim: "Highlights the area that most influenced
//  this assessment. Not a lesion outline."
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/cam_overlay.dart';

class CamScreen extends StatefulWidget {
  final File imageFile;
  final List<double> camMap;

  const CamScreen({
    super.key,
    required this.imageFile,
    required this.camMap,
  });

  @override
  State<CamScreen> createState() => _CamScreenState();
}

class _CamScreenState extends State<CamScreen> {
  double _opacity = 0.45; // Default specified in §3.9

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        foregroundColor: AppTheme.paper,
        title: const Text('Region of interest'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  child: AspectRatio(
                    aspectRatio: 1, // Model sees 1:1 (224x224)
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          widget.imageFile,
                          fit: BoxFit.cover,
                        ),
                        Opacity(
                          opacity: _opacity,
                          child: CamOverlay(camMap: widget.camMap),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppTheme.ink,
                border: Border(top: BorderSide(color: AppTheme.slate)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.visibility_off, color: AppTheme.slateSoft, size: 20),
                      Expanded(
                        child: Slider(
                          value: _opacity,
                          min: 0,
                          max: 1,
                          activeColor: AppTheme.aperture,
                          inactiveColor: AppTheme.slate,
                          onChanged: (v) => setState(() => _opacity = v),
                        ),
                      ),
                      const Icon(Icons.visibility, color: AppTheme.slateSoft, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Highlights the area that most influenced this assessment. Not a lesion outline.',
                    style: AppTheme.body(size: 13, color: AppTheme.paper, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
