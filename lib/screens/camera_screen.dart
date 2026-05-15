import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/gesture_model.dart';
import '../services/camera_service.dart';
import '../services/gesture_detector.dart' as gesture_service;

/// Camera screen with gesture detection
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraService _cameraService = CameraService();
  late final gesture_service.GestureDetector _gestureDetector;

  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _showOverlay = true;
  GestureResult? _lastDetectedGesture;
  String _detectionStatus = 'Initializing camera...';

  @override
  void initState() {
    super.initState();
    _gestureDetector = gesture_service.GestureDetector(_cameraService);
    _initializeCamera();

    // Listen to gesture detections
    _gestureDetector.gestureStream.listen((result) {
      _handleGestureDetected(result);
    });
  }

  @override
  void dispose() {
    _gestureDetector.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint('Starting camera initialization...');
      final initialized = await _cameraService.initialize();
      if (!mounted) return;
      if (!initialized) {
        setState(() {
          _detectionStatus = 'Camera not available. Please allow camera access.';
        });
        return;
      }

      final started = await _cameraService.startCamera();
      if (!mounted) return;
      if (!started || _cameraService.controller == null) {
        setState(() {
          _detectionStatus = 'Failed to start camera. Please try again.';
        });
        return;
      }

      debugPrint('Camera controller is initialized: ${_cameraService.controller!.value.isInitialized}');

      setState(() {
        _isInitialized = true;
        _detectionStatus = kIsWeb
            ? 'Camera ready - Demo mode'
            : 'Camera ready';
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      setState(() {
        _detectionStatus = 'Error: $e';
      });
    }
  }

  void _handleGestureDetected(GestureResult result) {
    if (!mounted) return;

    setState(() {
      _lastDetectedGesture = result;
      _detectionStatus = 'Detected: ${result.type.displayName}';
    });

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(result.type.icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.type.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Confidence: ${(result.confidence * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: result.type.color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleDetection() async {
    if (_isDetecting) {
      await _gestureDetector.stopDetection();
      setState(() {
        _isDetecting = false;
        _detectionStatus = 'Detection stopped';
      });
    } else {
      await _gestureDetector.startDetection();
      setState(() {
        _isDetecting = true;
        _detectionStatus = 'Detecting gestures...';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // slate-900
              Color(0xFF1E293B), // slate-800
              Color(0xFF334155), // slate-700
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Camera Feed
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCameraFeed(),
                ),
              ),

              // Bottom section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Gesture status
                    _buildGestureStatus(),

                    const SizedBox(height: 20),

                    // Controls
                    _buildControls(),

                    const SizedBox(height: 20),

                    // Instructions
                    _buildInstructions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.back_hand,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gesture Detection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
            kIsWeb ? 'Web Demo Mode' : 'Real-time Detection',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCameraFeed() {
    if (!_isInitialized) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.white.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _detectionStatus,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Retry Camera'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (_cameraService.controller != null &&
                _cameraService.controller!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _cameraService.controller!.value.aspectRatio,
                  child: CameraPreview(_cameraService.controller!),
                ),
              ),

            // Detection status overlay
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _isDetecting
                                ? const Color(0xFF10B981)
                                : Colors.grey,
                            shape: BoxShape.circle,
                            boxShadow: _isDetecting
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981)
                                          .withOpacity(0.5),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _detectionStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (kIsWeb)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'DEMO',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Last detected gesture
            if (_lastDetectedGesture != null && _showOverlay)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _GestureResultCard(
                  result: _lastDetectedGesture!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _lastDetectedGesture?.type.icon ?? Icons.question_mark,
                color: _lastDetectedGesture?.type.color ?? Colors.grey,
                size: 48,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lastDetectedGesture?.type.displayName ?? 'No gesture detected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _lastDetectedGesture?.type.description ?? 'Start detection to see gestures',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_lastDetectedGesture != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _lastDetectedGesture!.confidence,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _lastDetectedGesture!.type.color,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(_lastDetectedGesture!.confidence * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: _isDetecting ? Icons.stop : Icons.play_arrow,
          label: _isDetecting ? 'Stop' : 'Start',
          color: _isDetecting
              ? const Color(0xFFEF4444)
              : const Color(0xFF10B981),
          onTap: _toggleDetection,
        ),
        const SizedBox(width: 12),
        _ControlButton(
          icon: _showOverlay ? Icons.visibility : Icons.visibility_off,
          label: _showOverlay ? 'Hide' : 'Show',
          color: Colors.white.withOpacity(0.2),
          onTap: () {
            setState(() {
              _showOverlay = !_showOverlay;
            });
          },
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Supported Gestures',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: GestureType.values
                .where((g) => g != GestureType.unknown)
                .map((gesture) => _GestureChip(gestureType: gesture))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            kIsWeb
                ? 'Note: Web demo uses simulated gestures for demonstration.'
                : 'Point your hand at the camera to detect gestures.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Gesture result card
class _GestureResultCard extends StatelessWidget {
  final GestureResult result;

  const _GestureResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: result.type.color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: result.type.color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            result.type.icon,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.type.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  result.type.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(result.confidence * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gesture chip widget
class _GestureChip extends StatelessWidget {
  final GestureType gestureType;

  const _GestureChip({required this.gestureType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: gestureType.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gestureType.color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gestureType.icon,
            color: gestureType.color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            gestureType.displayName,
            style: TextStyle(
              color: gestureType.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Control button
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}