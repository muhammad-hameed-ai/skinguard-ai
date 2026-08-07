// ═══════════════════════════════════════════════════════════════
//  Preprocessing — decode, quality check, resize, normalise NCHW
//
//  §4.1  RESIZE + NORMALISE ONLY.  No hair removal, colour
//        constancy, or CLAHE.  Those cleaned the dataset; they
//        were never applied during training.
//
//  §4.2  Layout is NCHW (channels-first).
//        out[0*plane + i] = r
//        out[1*plane + i] = g
//        out[2*plane + i] = b
//
//  §7.5  Laplacian blur threshold is 12, not 50.
//        Dermoscopy images have smooth lesions on smooth skin;
//        50 rejects ~50 % of valid images.
// ═══════════════════════════════════════════════════════════════

import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

// ── ImageNet normalisation constants ─────────────────────────
const _mean = [0.485, 0.456, 0.406];
const _std  = [0.229, 0.224, 0.225];

const _targetSize = 224;

// ── Quality thresholds (§5 step 2, §7.5) ────────────────────
const _blurThreshold       = 12.0;
const _brightnessMin       = 35.0;
const _brightnessMax       = 225.0;

// ── Quality check result ────────────────────────────────────
class QualityResult {
  final bool ok;
  final String? reason;
  final double laplacianVariance;
  final double meanBrightness;

  const QualityResult({
    required this.ok,
    this.reason,
    required this.laplacianVariance,
    required this.meanBrightness,
  });
}

// ── Public API ──────────────────────────────────────────────

/// Decodes raw file bytes into an [img.Image].
/// Returns null if the bytes cannot be decoded.
img.Image? decodeImage(Uint8List bytes) {
  return img.decodeImage(bytes);
}

/// Client-side quality check (~20 ms, no model).
///
/// Checks:
///   - Laplacian variance >= 12  (blur detection)
///   - Mean brightness in [35, 225]
QualityResult qualityCheck(img.Image image) {
  // Work on a small greyscale copy for speed.
  final grey = img.grayscale(
    img.copyResize(image, width: 128, height: 128),
  );

  final w = grey.width;
  final h = grey.height;

  // ── Laplacian variance (3×3 kernel) ──────────────────────
  // kernel:  0  1  0
  //          1 -4  1
  //          0  1  0
  double lapSum  = 0;
  double lapSq   = 0;
  int    lapN    = 0;

  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final c  = grey.getPixel(x, y).r.toDouble();
      final n  = grey.getPixel(x, y - 1).r.toDouble();
      final s  = grey.getPixel(x, y + 1).r.toDouble();
      final ww = grey.getPixel(x - 1, y).r.toDouble();
      final e  = grey.getPixel(x + 1, y).r.toDouble();

      final lap = (n + s + ww + e) - 4 * c;
      lapSum += lap;
      lapSq  += lap * lap;
      lapN++;
    }
  }

  final lapMean = lapSum / lapN;
  final lapVar  = (lapSq / lapN) - (lapMean * lapMean);

  // ── Mean brightness ──────────────────────────────────────
  double brightSum = 0;
  final totalPixels = w * h;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      brightSum += grey.getPixel(x, y).r.toDouble();
    }
  }
  final meanBright = brightSum / totalPixels;

  // ── Decision ─────────────────────────────────────────────
  if (lapVar < _blurThreshold) {
    return QualityResult(
      ok: false,
      reason: 'Image is too blurry. Please hold the camera steady and retake.',
      laplacianVariance: lapVar,
      meanBrightness: meanBright,
    );
  }
  if (meanBright < _brightnessMin) {
    return QualityResult(
      ok: false,
      reason: 'Image is too dark. Please improve lighting and retake.',
      laplacianVariance: lapVar,
      meanBrightness: meanBright,
    );
  }
  if (meanBright > _brightnessMax) {
    return QualityResult(
      ok: false,
      reason: 'Image is overexposed. Please reduce lighting and retake.',
      laplacianVariance: lapVar,
      meanBrightness: meanBright,
    );
  }

  return QualityResult(
    ok: true,
    laplacianVariance: lapVar,
    meanBrightness: meanBright,
  );
}

/// Resizes to 224×224, normalises to ImageNet mean/std, and
/// packs into NCHW [Float32List] of shape [1, 3, 224, 224].
///
/// This is the ONLY preprocessing applied — §4.1 forbids any
/// additional transforms (hair removal, CLAHE, colour constancy).
Float32List preprocessForModel(img.Image image) {
  // Resize to exactly 224×224 using bilinear interpolation.
  final resized = img.copyResize(
    image,
    width: _targetSize,
    height: _targetSize,
    interpolation: img.Interpolation.linear,
  );

  final plane = _targetSize * _targetSize;        // 50176
  final buffer = Float32List(1 * 3 * plane);       // [1,3,224,224]

  for (int y = 0; y < _targetSize; y++) {
    for (int x = 0; x < _targetSize; x++) {
      final pixel = resized.getPixel(x, y);
      final i = y * _targetSize + x;

      // px / 255.0 → normalise with ImageNet mean and std.
      final r = (pixel.r.toDouble() / 255.0 - _mean[0]) / _std[0];
      final g = (pixel.g.toDouble() / 255.0 - _mean[1]) / _std[1];
      final b = (pixel.b.toDouble() / 255.0 - _mean[2]) / _std[2];

      // NCHW: all red values first, then green, then blue.
      buffer[0 * plane + i] = r;
      buffer[1 * plane + i] = g;
      buffer[2 * plane + i] = b;
    }
  }

  return buffer;
}
