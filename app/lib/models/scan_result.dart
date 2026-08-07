// ═══════════════════════════════════════════════════════════════
//  ScanResult — immutable data class for the full inference chain
//
//  Holds gate verdicts, both head probabilities, CAM data, risk
//  band, human-readable label and recommendation. Every field is
//  set once by InferenceService and never mutated.
// ═══════════════════════════════════════════════════════════════

/// Why the OOD gate rejected an image (or accepted it).
enum GateVerdict {
  accepted,
  wound,
  notLesion,
  qualityFail,
}

/// Clinical risk band derived from the two head probabilities.
enum RiskBand {
  low,
  moderate,
  high,
  veryHigh,
}

class ScanResult {
  // ── Gate ────────────────────────────────────────────────────
  final double gateValidProb;
  final double gateWoundProb;
  final double gateNotLesionProb;
  final GateVerdict verdict;

  bool get wasAccepted => verdict == GateVerdict.accepted;

  // ── Melanoma head (primary) ────────────────────────────────
  final double melanomaRaw;      // raw logit
  final double melanomaProb;     // calibrated probability [0,1]
  final bool   melanomaFlagged;  // >= threshold after isotonic

  // ── Cancer head (safety) ───────────────────────────────────
  final double cancerRaw;
  final double cancerProb;
  final bool   cancerFlagged;

  // ── CAM ────────────────────────────────────────────────────
  /// 49 floats (7×7), or null when gate rejected.
  final List<double>? camMap;

  // ── Derived ────────────────────────────────────────────────
  final RiskBand risk;
  final String   label;
  final String   recommendation;
  final int      inferenceMs;

  const ScanResult({
    required this.gateValidProb,
    required this.gateWoundProb,
    required this.gateNotLesionProb,
    required this.verdict,
    this.melanomaRaw   = 0,
    this.melanomaProb  = 0,
    this.melanomaFlagged = false,
    this.cancerRaw     = 0,
    this.cancerProb    = 0,
    this.cancerFlagged = false,
    this.camMap,
    required this.risk,
    required this.label,
    required this.recommendation,
    required this.inferenceMs,
  });

  // ── Display helpers ────────────────────────────────────────

  /// Percentage string clamped to 1–99% (§4.4: never show 0% or 100%).
  String get melanomaPercent =>
      '${(melanomaProb.clamp(0.01, 0.99) * 100).toStringAsFixed(1)}%';

  String get cancerPercent =>
      '${(cancerProb.clamp(0.01, 0.99) * 100).toStringAsFixed(1)}%';

  // ── Risk assignment ────────────────────────────────────────

  /// Assigns risk band from the calibrated melanoma probability.
  /// Bands are deliberately asymmetric: the cost of missing a
  /// melanoma far exceeds the cost of a false referral.
  static RiskBand computeRisk(double melProb, double cancerProb) {
    if (melProb >= 0.60)  return RiskBand.veryHigh;
    if (melProb >= 0.385) return RiskBand.high;      // at threshold
    if (cancerProb >= 0.44) return RiskBand.moderate; // cancer flagged alone
    return RiskBand.low;
  }

  static String labelFor(RiskBand risk, GateVerdict verdict) {
    if (verdict == GateVerdict.wound) {
      return 'Image appears to show a wound, not a skin lesion.';
    }
    if (verdict == GateVerdict.notLesion) {
      return 'Image does not appear to show a skin lesion.';
    }
    if (verdict == GateVerdict.qualityFail) {
      return 'Image quality is insufficient for analysis.';
    }
    switch (risk) {
      case RiskBand.veryHigh:
        return 'High melanoma risk detected.';
      case RiskBand.high:
        return 'Elevated melanoma risk detected.';
      case RiskBand.moderate:
        return 'Moderate cancer risk detected.';
      case RiskBand.low:
        return 'Low risk. No immediate concerns.';
    }
  }

  static String recommendationFor(RiskBand risk, GateVerdict verdict) {
    if (verdict != GateVerdict.accepted) {
      return 'Please retake the photo with a clear view of the skin lesion.';
    }
    switch (risk) {
      case RiskBand.veryHigh:
      case RiskBand.high:
        return 'Consult a dermatologist as soon as possible. '
               'This is a screening aid, not a diagnosis.';
      case RiskBand.moderate:
        return 'Consider consulting a dermatologist for further evaluation. '
               'This is a screening aid, not a diagnosis.';
      case RiskBand.low:
        return 'Continue regular self-examination. '
               'Consult a dermatologist if the lesion changes. '
               'This is a screening aid, not a diagnosis.';
    }
  }

  /// Convenience factory for a gate-rejected result.
  factory ScanResult.rejected({
    required double gateValidProb,
    required double gateWoundProb,
    required double gateNotLesionProb,
    required GateVerdict verdict,
    required int inferenceMs,
  }) {
    return ScanResult(
      gateValidProb: gateValidProb,
      gateWoundProb: gateWoundProb,
      gateNotLesionProb: gateNotLesionProb,
      verdict: verdict,
      risk: RiskBand.low,
      label: labelFor(RiskBand.low, verdict),
      recommendation: recommendationFor(RiskBand.low, verdict),
      inferenceMs: inferenceMs,
    );
  }
}
