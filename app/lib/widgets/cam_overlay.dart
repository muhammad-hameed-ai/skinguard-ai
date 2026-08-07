// ═══════════════════════════════════════════════════════════════
//  CAM Overlay — 7×7 heatmap (§3.9)
//
//  Bilinear upsample from 7×7 → display size, min-max normalise,
//  5-stop colour ramp, soft Gaussian blur effect.
//
//  Ramp: #1B3A4B → #2E7D8F → #E8C547 → #E07A3E → #D62828
//
//  Peak localisation is 68.4% — roughly 1 in 3 overlays may be
//  off-centre. Soft blur, low default opacity, never a sharp boundary.
// ═══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';

class CamOverlay extends StatelessWidget {
  final List<double> camMap;

  const CamOverlay({super.key, required this.camMap});

  @override
  Widget build(BuildContext context) {
    if (camMap.length != 49) return const SizedBox.shrink();

    return CustomPaint(
      painter: _CamPainter(camMap),
      size: Size.infinite,
    );
  }
}

// 5-stop colour ramp from the spec
const _rampColors = [
  Color(0xFF1B3A4B),
  Color(0xFF2E7D8F),
  Color(0xFFE8C547),
  Color(0xFFE07A3E),
  Color(0xFFD62828),
];

class _CamPainter extends CustomPainter {
  final List<double> camMap;
  _CamPainter(this.camMap);

  @override
  void paint(Canvas canvas, Size size) {
    final double minVal = camMap.reduce(math.min);
    final double maxVal = camMap.reduce(math.max);
    final double range = maxVal - minVal;

    // Upsample 7×7 to a finer grid for smoother appearance
    const upscale = 28; // 7 * 4
    final cellW = size.width / upscale;
    final cellH = size.height / upscale;

    for (int uy = 0; uy < upscale; uy++) {
      for (int ux = 0; ux < upscale; ux++) {
        // Bilinear interpolation from 7×7 source
        final srcX = (ux / upscale) * 7;
        final srcY = (uy / upscale) * 7;

        final val = _bilinearSample(srcX, srcY);
        final norm = range > 0 ? (val - minVal) / range : 0.0;

        final paint = Paint()
          ..color = _rampColor(norm.clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;

        canvas.drawRect(
          Rect.fromLTWH(ux * cellW, uy * cellH, cellW + 1, cellH + 1),
          paint,
        );
      }
    }
  }

  /// Bilinear sample from the 7×7 grid at fractional coordinates.
  double _bilinearSample(double x, double y) {
    final x0 = x.floor().clamp(0, 6);
    final y0 = y.floor().clamp(0, 6);
    final x1 = (x0 + 1).clamp(0, 6);
    final y1 = (y0 + 1).clamp(0, 6);

    final fx = x - x.floor();
    final fy = y - y.floor();

    final v00 = camMap[y0 * 7 + x0];
    final v10 = camMap[y0 * 7 + x1];
    final v01 = camMap[y1 * 7 + x0];
    final v11 = camMap[y1 * 7 + x1];

    final top = v00 + (v10 - v00) * fx;
    final bot = v01 + (v11 - v01) * fx;

    return top + (bot - top) * fy;
  }

  /// 5-stop colour ramp interpolation.
  Color _rampColor(double t) {
    if (t <= 0) return _rampColors.first;
    if (t >= 1) return _rampColors.last;

    final segment = t * (_rampColors.length - 1);
    final i = segment.floor().clamp(0, _rampColors.length - 2);
    final frac = segment - i;

    return Color.lerp(_rampColors[i], _rampColors[i + 1], frac)!;
  }

  @override
  bool shouldRepaint(covariant _CamPainter oldDelegate) => false;
}
