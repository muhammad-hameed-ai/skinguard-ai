// ═══════════════════════════════════════════════════════════════
//  Capture Screen (Replaces ImagePicker for camera) (§3.5)
//
//  Live camera feed. Dashed circular framing guide in center.
//  Caption: "Fill the circle".
//  Gallery and Flash controls.
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/image_storage.dart';
import 'processing_screen.dart';
import 'dart:math' as math;

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No cameras found on device');
        return;
      }
      
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);
      
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        setState(() => _isFlashOn = false);
      } else {
        await _controller!.setFlashMode(FlashMode.torch); // Torch is better for derm mode
        setState(() => _isFlashOn = true);
      }
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      final xFile = await _controller!.takePicture();
      // Turn off flash if it was on
      if (_isFlashOn) await _toggleFlash();
      
      if (!mounted) return;
      _processImage(File(xFile.path));
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  Future<void> _pickGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null || !mounted) return;
    
    _processImage(File(picked.path));
  }

  Future<void> _processImage(File file) async {
    final stored = await ImageStorage.persist(file);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ProcessingScreen(imageFile: stored)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.ink,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
        body: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
      );
    }

    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: AppTheme.ink,
        body: Center(child: CircularProgressIndicator(color: AppTheme.aperture)),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          
          // Custom Overlay
          CustomPaint(
            size: size,
            painter: _FramingGuidePainter(),
          ),
          
          // "Fill the circle" text
          Positioned(
            top: size.height / 2 - 170, // Just above the circle
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Fill the circle', 
                      style: AppTheme.body(color: Colors.white, size: 14, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Centre the mole or spot inside the circle', 
                      style: AppTheme.body(color: Colors.white70, size: 12)),
                  ],
                ),
              ),
            ),
          ),
          
          // Top controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                IconButton(
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: _isFlashOn ? AppTheme.signal : Colors.white,
                    size: 28,
                  ),
                  onPressed: _toggleFlash,
                ),
              ],
            ),
          ),
          
          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button
                IconButton(
                  icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
                  onPressed: _pickGallery,
                ),
                
                // Shutter button
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Empty space to balance the row
                const SizedBox(width: 48), 
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FramingGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Darken everything outside the circle
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4; // 80% of width
    
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
      
    final combinedPath = Path.combine(PathOperation.difference, path, circlePath);
    
    canvas.drawPath(
      combinedPath, 
      Paint()..color = Colors.black.withOpacity(0.5)
    );
    
    // Draw dashed white circle
    final dashPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
      
    const dashLength = 10.0;
    const dashSpace = 8.0;
    final circumference = 2 * math.pi * radius;
    final numDashes = (circumference / (dashLength + dashSpace)).floor();
    final anglePerDash = (2 * math.pi) / numDashes;
    
    for (int i = 0; i < numDashes; i++) {
      final startAngle = i * anglePerDash;
      final endAngle = startAngle + (dashLength / radius);
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
        false,
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
