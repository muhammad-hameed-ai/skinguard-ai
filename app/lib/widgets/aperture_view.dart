// ═══════════════════════════════════════════════════════════════
//  ApertureView — the signature element (§2.3)
//
//  A circular field with a calibration ring, borrowed from what
//  a clinician sees through a dermoscope. Appears on 11 screens.
//
//  Built ONCE, parameterised. Do not duplicate across screens.
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ApertureView extends StatelessWidget {
  final double size;
  final ImageProvider? image;
  final bool showRing;
  final Widget? overlay;
  final double overlayOpacity;

  const ApertureView({
    super.key,
    required this.size,
    this.image,
    this.showRing = true,
    this.overlay,
    this.overlayOpacity = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle with image or gradient placeholder
          ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: image != null
                  ? Image(
                      image: image!,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.apertureLt,
                            AppTheme.aperture,
                            AppTheme.ink,
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
            ),
          ),

          // CAM overlay
          if (overlay != null)
            ClipOval(
              child: SizedBox(
                width: size,
                height: size,
                child: Opacity(
                  opacity: overlayOpacity,
                  child: overlay,
                ),
              ),
            ),

          // Calibration ring with tick marks
          if (showRing)
            CustomPaint(
              size: Size(size, size),
              painter: _CalibrationRingPainter(),
            ),
        ],
      ),
    );
  }
}

class _CalibrationRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // White ring
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius - 4, ringPaint);

    // Tick marks at top, bottom, left, right
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const tickLength = 8.0;
    final tickRadius = radius - 4;

    // Top tick
    canvas.drawLine(
      Offset(center.dx, center.dy - tickRadius - tickLength / 2),
      Offset(center.dx, center.dy - tickRadius + tickLength / 2),
      tickPaint,
    );
    // Bottom tick
    canvas.drawLine(
      Offset(center.dx, center.dy + tickRadius - tickLength / 2),
      Offset(center.dx, center.dy + tickRadius + tickLength / 2),
      tickPaint,
    );

    // Small graduation marks around the ring (every 30 degrees)
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final innerR = tickRadius - 3;
      final outerR = tickRadius + 3;

      canvas.drawLine(
        Offset(
          center.dx + innerR * math.cos(angle),
          center.dy + innerR * math.sin(angle),
        ),
        Offset(
          center.dx + outerR * math.cos(angle),
          center.dy + outerR * math.sin(angle),
        ),
        tickPaint..strokeWidth = (i % 3 == 0) ? 2.0 : 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
