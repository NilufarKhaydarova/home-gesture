import 'dart:async';
import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Camera service for handling camera initialization and control
class CameraService {
  CameraController? controller;
  List<CameraDescription>? cameras;

  final StreamController<String> _stateController =
      StreamController<String>.broadcast();

  Stream<String> get stateStream => _stateController.stream;
  StreamController<CameraImage>? _frameStream;

  CameraDescription? get currentCamera =>
      cameras != null && cameras!.isNotEmpty ? cameras![0] : null;

  bool get isInitialized => controller?.value.isInitialized ?? false;

  /// Initialize camera
  Future<bool> initialize() async {
    try {
      debugPrint('Getting available cameras...');
      cameras = await availableCameras();
      debugPrint('Found ${cameras?.length ?? 0} cameras');

      if (cameras == null || cameras!.isEmpty) {
        _stateController.add('No cameras available');
        return false;
      }

      // On web, use the first available camera
      // On mobile, prefer front camera
      CameraDescription camera = cameras![0];
      debugPrint('Using camera: ${camera.name}');

      controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      debugPrint('Initializing camera controller...');
      await controller!.initialize();
      debugPrint('Camera initialized successfully');
      _stateController.add('Camera initialized');
      return true;
    } catch (e) {
      _stateController.add('Camera initialization error: $e');
      debugPrint('Camera initialization error: $e');
      return false;
    }
  }

  /// Start camera
  Future<bool> startCamera() async {
    if (controller == null) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (!isInitialized) {
      return false;
    }

    _stateController.add('Camera started');
    return true;
  }

  /// Start streaming camera frames
  void startFrameStream() {
    if (controller == null || !isInitialized) return;

    _frameStream = StreamController<CameraImage>.broadcast();
    controller!.startImageStream((image) {
      if (_frameStream != null && !_frameStream!.isClosed) {
        _frameStream!.add(image);
      }
    });
  }

  /// Stop streaming camera frames
  void stopFrameStream() {
    _frameStream?.close();
    _frameStream = null;
  }

  Stream<CameraImage>? get frameStream => _frameStream?.stream;

  /// Dispose resources
  void dispose() {
    stopFrameStream();
    controller?.dispose();
    controller = null;
    _stateController.close();
  }
}