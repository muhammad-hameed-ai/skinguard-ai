// ═══════════════════════════════════════════════════════════════
//  InferenceService — three-model ONNX cascade
//
//  Chain (§5):
//    1. decode + quality check  (Dart, ~20 ms)
//    2. resize 224 + normalise + NCHW
//    3. ood_gate.onnx  → softmax → reject unless p[valid] >= 0.85
//    4. melanoma_head  → logit_melanoma → calibrate → >= 0.385
//    5. cancer_head    → logit_cancer   → calibrate → >= 0.44
//    6. CAM from melanoma output (7×7 = 49 values)
//
//  Singleton with lazy init. All three ONNX sessions stay alive
//  for the lifetime of the app.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';

import 'preprocessing.dart';
import 'calibration.dart';
import '../models/scan_result.dart';

class InferenceService {
  InferenceService._();
  static final InferenceService instance = InferenceService._();

  // ── ONNX sessions ─────────────────────────────────────────
  OrtSession? _gateSession;
  OrtSession? _melanomaSession;
  OrtSession? _cancerSession;

  // ── Config loaded from deploy_config.json ──────────────────
  late double _gateThreshold;
  late double _melTemperature;
  late double _melThreshold;
  late double _canTemperature;
  late double _canThreshold;

  bool _initialized = false;

  /// Whether all three models are loaded and ready.
  bool get isInitialized => _initialized;

  /// Loads all three models and the calibration curves.
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialise ONNX Runtime environment.
    OrtEnv.instance.init();

    const required = [
      'assets/models/melanoma_head.onnx',
      'assets/models/cancer_head.onnx',
      'assets/models/ood_gate.onnx',
      'assets/models/deploy_config.json',
      'assets/models/calibration_curves.json',
    ];

    final missing = <String>[];
    for (final path in required) {
      try {
        await rootBundle.load(path);
      } catch (_) {
        missing.add(path);
      }
    }
    if (missing.isNotEmpty) {
      throw Exception('Missing model assets: ${missing.join(", ")}');
    }

    // Load deploy config.
    final configRaw = await rootBundle.loadString(
      'assets/models/deploy_config.json',
    );
    final config = jsonDecode(configRaw) as Map<String, dynamic>;

    final models = config['models'] as Map<String, dynamic>;
    _gateThreshold = (models['ood_gate']['accept_threshold'] as num).toDouble();
    _melTemperature = (models['melanoma']['temperature'] as num).toDouble();
    _melThreshold   = (models['melanoma']['threshold'] as num).toDouble();
    _canTemperature = (models['cancer']['temperature'] as num).toDouble();
    _canThreshold   = (models['cancer']['threshold'] as num).toDouble();

    // Load calibration curves.
    await CalibrationService.instance.load();

    // Create ONNX sessions from asset bytes.
    final sessionOpts = OrtSessionOptions();

    final gateBytes = await rootBundle.load('assets/models/ood_gate.onnx');
    _gateSession = OrtSession.fromBuffer(
      gateBytes.buffer.asUint8List(), sessionOpts,
    );

    final melBytes = await rootBundle.load('assets/models/melanoma_head.onnx');
    _melanomaSession = OrtSession.fromBuffer(
      melBytes.buffer.asUint8List(), sessionOpts,
    );

    final canBytes = await rootBundle.load('assets/models/cancer_head.onnx');
    _cancerSession = OrtSession.fromBuffer(
      canBytes.buffer.asUint8List(), sessionOpts,
    );

    sessionOpts.release();
    _initialized = true;
  }

  /// Runs a dummy zeroed tensor through the full pipeline to
  /// pre-allocate ONNX graph memory. Call during splash so the
  /// user's first real scan feels instant (§3.1).
  ///
  /// First inference: ~1900 ms. Warm inference: ~680 ms.
  Future<void> warmUp() async {
    assert(_initialized, 'Call initialize() before warmUp()');
    final dummy = Float32List(1 * 3 * 224 * 224); // zeroed
    // Run gate only — enough to allocate the shared memory.
    _runGate(dummy);
    _runMelanoma(dummy);
    _runCancer(dummy);
  }

  /// Runs the full inference chain on [imageFile].
  ///
  /// Returns a [ScanResult] with gate verdicts, calibrated
  /// probabilities, CAM data, risk band, and timing.
  Future<ScanResult> analyze(File imageFile) async {
    assert(_initialized, 'Call initialize() before analyze()');

    final stopwatch = Stopwatch()..start();

    // ── 1. Read and decode ──────────────────────────────────
    final bytes = await imageFile.readAsBytes();
    final decoded = decodeImage(bytes);
    if (decoded == null) {
      throw ArgumentError('Could not decode image: ${imageFile.path}');
    }

    // ── 2. Quality check ────────────────────────────────────
    final quality = qualityCheck(decoded);
    if (!quality.ok) {
      stopwatch.stop();
      return ScanResult.rejected(
        gateValidProb: 0,
        gateWoundProb: 0,
        gateNotLesionProb: 0,
        verdict: GateVerdict.qualityFail,
        inferenceMs: stopwatch.elapsedMilliseconds,
      );
    }

    // ── 3. Preprocess (resize 224, normalise, NCHW) ─────────
    final inputBuffer = preprocessForModel(decoded);

    // ── 4. OOD gate ─────────────────────────────────────────
    final gateProbs = _runGate(inputBuffer);
    final validProb     = gateProbs[0];
    final woundProb     = gateProbs[1];
    final notLesionProb = gateProbs[2];

    if (validProb < _gateThreshold) {
      stopwatch.stop();
      // Determine which rejection class won.
      final verdict = woundProb > notLesionProb
          ? GateVerdict.wound
          : GateVerdict.notLesion;
      return ScanResult.rejected(
        gateValidProb: validProb,
        gateWoundProb: woundProb,
        gateNotLesionProb: notLesionProb,
        verdict: verdict,
        inferenceMs: stopwatch.elapsedMilliseconds,
      );
    }

    // ── 5. Melanoma head ────────────────────────────────────
    final melResult = _runMelanoma(inputBuffer);
    final melLogit  = melResult.logit;
    final camValues = melResult.cam;

    final melProb = CalibrationService.instance.calibrate(
      melLogit,
      temperature: _melTemperature,
      head: 'melanoma',
    );
    final melFlagged = melProb >= _melThreshold;

    // ── 6. Cancer head ──────────────────────────────────────
    final canLogit = _runCancer(inputBuffer);

    final canProb = CalibrationService.instance.calibrate(
      canLogit,
      temperature: _canTemperature,
      head: 'cancer',
    );
    final canFlagged = canProb >= _canThreshold;

    // ── 7. Assemble result ──────────────────────────────────
    stopwatch.stop();

    final risk = ScanResult.computeRisk(melProb, canProb);

    return ScanResult(
      gateValidProb: validProb,
      gateWoundProb: woundProb,
      gateNotLesionProb: notLesionProb,
      verdict: GateVerdict.accepted,
      melanomaRaw: melLogit,
      melanomaProb: melProb,
      melanomaFlagged: melFlagged,
      cancerRaw: canLogit,
      cancerProb: canProb,
      cancerFlagged: canFlagged,
      camMap: camValues,
      risk: risk,
      label: ScanResult.labelFor(risk, GateVerdict.accepted),
      recommendation: ScanResult.recommendationFor(risk, GateVerdict.accepted),
      inferenceMs: stopwatch.elapsedMilliseconds,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  Private model runners
  // ═══════════════════════════════════════════════════════════

  /// Runs the OOD gate and returns softmax probabilities
  /// [valid_lesion, wound, not_lesion].
  List<double> _runGate(Float32List input) {
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      input, [1, 3, 224, 224],
    );

    final outputs = _gateSession!.run(
      OrtRunOptions(), {'image': inputOrt},
    );

    // Output: logits [1, 3]
    final logits = (outputs[0]?.value as List<List<double>>)[0];
    inputOrt.release();
    for (final o in outputs) { o?.release(); }

    return _softmax(logits);
  }

  /// Result from the melanoma model: logit + CAM.
  _MelanomaOutput _runMelanoma(Float32List input) {
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      input, [1, 3, 224, 224],
    );

    final outputs = _melanomaSession!.run(
      OrtRunOptions(), {'image': inputOrt},
    );

    // Output 0: logit_melanoma [1, 1]
    final logitMel = _extractScalar(outputs[0]!.value);

    // Output 2: cam [1, 1, 7, 7]  (index 2, after logit_cancer)
    List<double>? cam;
    if (outputs.length > 2 && outputs[2] != null) {
      cam = _flattenToDoubles(outputs[2]!.value);
    }

    inputOrt.release();
    for (final o in outputs) { o?.release(); }

    return _MelanomaOutput(logit: logitMel, cam: cam);
  }

  /// Runs the cancer head and returns the cancer logit.
  double _runCancer(Float32List input) {
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      input, [1, 3, 224, 224],
    );

    final outputs = _cancerSession!.run(
      OrtRunOptions(), {'image': inputOrt},
    );

    // Output 1: logit_cancer [1, 1]
    // The cancer head has the same output structure; use logit_cancer.
    final logitCancer = _extractScalar(outputs[1]!.value);

    inputOrt.release();
    for (final o in outputs) { o?.release(); }

    return logitCancer;
  }

  // ═══════════════════════════════════════════════════════════
  //  Utility methods
  // ═══════════════════════════════════════════════════════════

  static List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  /// Extracts a scalar from arbitrarily nested lists (e.g. [[0.5]]).
  static double _extractScalar(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is List) return _extractScalar(value[0]);
    throw ArgumentError('Cannot extract scalar from $value');
  }

  /// Recursively flattens nested lists into a flat List<double>.
  static List<double> _flattenToDoubles(dynamic value) {
    if (value is double) return [value];
    if (value is num) return [value.toDouble()];
    if (value is List) {
      return value.expand((e) => _flattenToDoubles(e)).toList();
    }
    throw ArgumentError('Cannot flatten $value');
  }

  /// Releases all ONNX sessions. Call when the app is done.
  void dispose() {
    _gateSession?.release();
    _melanomaSession?.release();
    _cancerSession?.release();
    _gateSession = null;
    _melanomaSession = null;
    _cancerSession = null;
    _initialized = false;
  }
}

class _MelanomaOutput {
  final double logit;
  final List<double>? cam;
  const _MelanomaOutput({required this.logit, this.cam});
}
