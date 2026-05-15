import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../features/automation/simple_automation.dart';
import '../gesture_detection/gesture_detector.dart' as gesture_detection;
import 'camera_service.dart' as camera_service;

/// Camera screen with gesture detection
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  final camera_service.CameraService _cameraService =
      camera_service.CameraService();
  late final gesture_detection.GestureDetector _gestureDetector;
  StreamSubscription<camera_service.CameraState>? _cameraStateSubscription;

  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _showOverlay = true;
  GestureResult? _lastDetectedGesture;
  String _detectionStatus = 'Ready';

  // Automation state
  bool _lightOn = true;
  bool _musicPlaying = false;
  bool _kitchenLightOn = false;
  String _lastGestureMessage = '';

  // Animation controllers
  late AnimationController _pulseController;

  final Map<String, DateTime> _lastGestureTime = {};

  @override
  void initState() {
    super.initState();
    _gestureDetector = gesture_detection.GestureDetector(_cameraService);
    _cameraStateSubscription = _cameraService.stateStream.listen((state) {
      if (!mounted) return;
      if (state is camera_service.CameraErrorState) {
        setState(() {
          _detectionStatus = 'Camera error: ${state.message}';
        });
      }
    });
    _initializeCamera();

    // Initialize animation controller
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cameraStateSubscription?.cancel();
    _gestureDetector.dispose();
    _cameraService.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final initialized = await _cameraService.initialize();
      if (!mounted) return;
      if (!initialized) {
        setState(() {
          _detectionStatus =
              'Camera permission denied or no camera found. Check system camera permissions.';
        });
        return;
      }

      final started = await _cameraService.startCamera();
      if (!mounted) return;
      if (!started || _cameraService.controller == null) {
        setState(() {
          _detectionStatus =
              'Failed to start camera. Please close other apps using camera and retry.';
        });
        return;
      }

      setState(() {
        _isInitialized = true;
        _detectionStatus = Platform.isMacOS
            ? 'Camera ready (preview mode on macOS)'
            : 'Camera ready';
      });

      // Listen to gesture detections
      _gestureDetector.gestureStream.listen((result) {
        _handleGestureDetected(result);
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

    // Debounce gestures (prevent triggering too frequently)
    final now = DateTime.now();
    final lastTime = _lastGestureTime[result.type.name] ?? DateTime(0);
    if (now.difference(lastTime).inSeconds < 2) return;

    _lastGestureTime[result.type.name] = now;

    String message = '';
    bool shouldUpdate = false;

    switch (result.type) {
      case GestureType.eyesClosed:
        _lightOn = false;
        message = 'Eyes closed - Turning off main light';
        shouldUpdate = true;
        break;
      case GestureType.wave:
        _musicPlaying = !_musicPlaying;
        message = _musicPlaying
            ? 'Wave detected - Playing music'
            : 'Wave detected - Stopping music';
        shouldUpdate = true;
        break;
      case GestureType.tummyRub:
        _kitchenLightOn = !_kitchenLightOn;
        message = _kitchenLightOn
            ? 'Tummy rub detected - Turning on kitchen'
            : 'Tummy rub detected - Turning off kitchen';
        shouldUpdate = true;
        break;
      default:
        break;
    }

    if (shouldUpdate) {
      setState(() {
        _lastDetectedGesture = result;
        _detectionStatus = 'Detected: ${result.type.displayName}';
        _lastGestureMessage = message;
      });

      // Show snackbar
      final action = SimpleAutomation.applyGesture(result.type);
      if (action != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(action.icon, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
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
            backgroundColor: action.color,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _resetAllDevices() {
    setState(() {
      _lightOn = true;
      _musicPlaying = false;
      _kitchenLightOn = false;
      _lastGestureMessage = '';
      _lastDetectedGesture = null;
    });
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
              Color(0xFF312E81), // indigo-900
              Color(0xFF581C87), // purple-900
              Color(0xFFBE185D), // pink-900
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildCameraFeed(),
                ),
              ),

              // Bottom section (scrollable)
              SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Last Gesture Detected
                      if (_lastGestureMessage.isNotEmpty)
                        _buildLastGestureBanner(),

                      // Automation Status Panel
                      _buildAutomationPanel(),

                      // Instructions
                      _buildInstructions(),

                      // Controls
                      _buildControls(),

                      const SizedBox(height: 16),
                    ],
                  ),
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.back_hand,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gesture Home Automation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Control your home with simple gestures',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
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
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
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
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                ),
                child: Text('Retry Camera'),
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
          color: Colors.white.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_cameraService.controller != null &&
                _cameraService.controller!.value.isInitialized)
              CameraPreview(_cameraService.controller!),

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
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _isDetecting ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Last detected gesture
            if (_lastDetectedGesture != null && _showOverlay)
              Positioned(
                top: 80,
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

  Widget _buildLastGestureBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _lastGestureMessage,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutomationPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DeviceCard(
                icon: Icons.lightbulb,
                label: 'Main Light',
                isOn: _lightOn,
                color: _lightOn ? const Color(0xFFFBBF24) : const Color(0xFF6B7280),
                hint: 'Close eyes for 10s',
                onColor: const Color(0xFFFEF3C7),
              ),
              const SizedBox(width: 16),
              _DeviceCard(
                icon: Icons.volume_up,
                label: 'Music',
                isOn: _musicPlaying,
                color: _musicPlaying ? const Color(0xFF3B82F6) : const Color(0xFF6B7280),
                hint: 'Wave hand',
                isPulsing: _musicPlaying,
                onColor: const Color(0xFFDBEAFE),
              ),
              const SizedBox(width: 16),
              _DeviceCard(
                icon: Icons.home,
                label: 'Kitchen Light',
                isOn: _kitchenLightOn,
                color: _kitchenLightOn ? const Color(0xFFEC4899) : const Color(0xFF6B7280),
                hint: 'Rub tummy',
                onColor: const Color(0xFFFCE7F3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Column(
              children: [
                Text(
                  'How to Use',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _InstructionCard(
                      emoji: '👁️',
                      title: 'Close Eyes',
                      description: 'Keep eyes closed for 10 seconds to turn off the main light',
                    ),
                    _InstructionCard(
                      emoji: '👋',
                      title: 'Wave Hand',
                      description: 'Raise your hand above your shoulder to toggle music',
                    ),
                    _InstructionCard(
                      emoji: '🤰',
                      title: 'Rub Tummy',
                      description: 'Place hand on stomach area to toggle kitchen light',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlButton(
            icon: _isDetecting ? Icons.stop : Icons.play_arrow,
            label: _isDetecting ? 'Stop' : 'Start',
            color: _isDetecting ? Colors.red : Colors.green,
            onTap: _toggleDetection,
          ),
          const SizedBox(width: 16),
          _ControlButton(
            icon: _showOverlay ? Icons.visibility : Icons.visibility_off,
            label: _showOverlay ? 'Hide' : 'Show',
            color: Colors.white.withValues(alpha: 0.3),
            onTap: () {
              setState(() {
                _showOverlay = !_showOverlay;
              });
            },
          ),
          const SizedBox(width: 16),
          _ControlButton(
            icon: Icons.refresh,
            label: 'Reset',
            color: Colors.white.withValues(alpha: 0.3),
            onTap: _resetAllDevices,
          ),
        ],
      ),
    );
  }

  void _toggleDetection() async {
    if (Platform.isMacOS) {
      setState(() {
        _isDetecting = false;
        _detectionStatus =
            'Gesture detection is disabled on macOS. Use iOS/Android for ML Kit processing.';
      });
      return;
    }

    if (_isDetecting) {
      await _gestureDetector.stopDetection();
      _cameraService.stopFrameStream();
      setState(() {
        _isDetecting = false;
        _detectionStatus = 'Detection stopped';
      });
    } else {
      await _cameraService.startFrameStream();
      await _gestureDetector.startDetection();
      setState(() {
        _isDetecting = true;
        _detectionStatus = 'Detecting...';
      });
    }
  }
}

/// Device card for automation panel
class _DeviceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isOn;
  final Color color;
  final String hint;
  final bool isPulsing;
  final Color onColor;

  const _DeviceCard({
    required this.icon,
    required this.label,
    required this.isOn,
    required this.color,
    required this.hint,
    this.isPulsing = false,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isOn ? onColor : const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedRotation(
            turns: isOn ? 0 : 0.5,
            duration: const Duration(milliseconds: 500),
            child: AnimatedScale(
              scale: isPulsing ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 600),
              child: Icon(
                icon,
                color: color,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: isOn ? const Color(0xFF1F2937) : const Color(0xFFD1D5DB),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isOn ? 'ON' : 'OFF',
            style: TextStyle(
              color: isOn ? const Color(0xFF4B5563) : const Color(0xFF6B7280),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Instruction card
class _InstructionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;

  const _InstructionCard({
    required this.emoji,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
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

/// Gesture result card
class _GestureResultCard extends StatelessWidget {
  final GestureResult result;

  const _GestureResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getGestureColor(result.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(result.confidence * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}