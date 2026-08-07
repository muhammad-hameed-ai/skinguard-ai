// ═══════════════════════════════════════════════════════════════
//  Calibration — temperature scaling + isotonic interpolation
//
//  §4.3  Two steps, both required:
//        1. pRaw   = sigmoid(logit / temperature)
//        2. pFinal = interpolate(pRaw, isotonicCurve)
//
//  Thresholds were tuned on the isotonic output (step 2).
//  Skipping step 2 compares a step-1 probability against a
//  step-2 threshold → wrong results, no error.
//
//  ECE improvement: 0.2235 → 0.0072.
//  When the app shows 77 %, the true rate is ~78 %.
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;

class CalibrationService {
  CalibrationService._();
  static final CalibrationService instance = CalibrationService._();

  late final List<double> _melanomaX;
  late final List<double> _melanomaY;
  late final List<double> _cancerX;
  late final List<double> _cancerY;

  bool _loaded = false;

  /// Loads the 200-point isotonic lookup tables from assets.
  /// Call once at startup; subsequent calls are no-ops.
  Future<void> load() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString(
      'assets/models/calibration_curves.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final mel = json['melanoma'] as Map<String, dynamic>;
    _melanomaX = (mel['x'] as List).cast<num>().map((n) => n.toDouble()).toList();
    _melanomaY = (mel['y'] as List).cast<num>().map((n) => n.toDouble()).toList();

    final can = json['cancer'] as Map<String, dynamic>;
    _cancerX = (can['x'] as List).cast<num>().map((n) => n.toDouble()).toList();
    _cancerY = (can['y'] as List).cast<num>().map((n) => n.toDouble()).toList();

    _loaded = true;
  }

  /// Full two-step calibration:
  ///   1. Temperature-scale the raw logit → sigmoid
  ///   2. Isotonic interpolation via the lookup table
  ///
  /// [head] must be `'melanoma'` or `'cancer'`.
  double calibrate(double rawLogit, {
    required double temperature,
    required String head,
  }) {
    assert(_loaded, 'CalibrationService.load() must be called first');

    // Step 1: temperature-scaled sigmoid
    final pRaw = _sigmoid(rawLogit / temperature);

    // Step 2: isotonic interpolation
    final List<double> xs;
    final List<double> ys;
    if (head == 'melanoma') {
      xs = _melanomaX;
      ys = _melanomaY;
    } else {
      xs = _cancerX;
      ys = _cancerY;
    }

    return _interpolate(pRaw, xs, ys);
  }

  // ── Internals ──────────────────────────────────────────────

  static double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  /// Linear interpolation through a sorted (x, y) lookup table.
  /// Clamps to the first/last y value outside the table range.
  static double _interpolate(double xVal, List<double> xs, List<double> ys) {
    if (xVal <= xs.first) return ys.first;
    if (xVal >= xs.last)  return ys.last;

    // Binary search for the interval containing xVal.
    int lo = 0;
    int hi = xs.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (xs[mid] <= xVal) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    // Linear interpolation between xs[lo] and xs[hi].
    final xRange = xs[hi] - xs[lo];
    if (xRange == 0) return ys[lo];

    final t = (xVal - xs[lo]) / xRange;
    return ys[lo] + t * (ys[hi] - ys[lo]);
  }
}
