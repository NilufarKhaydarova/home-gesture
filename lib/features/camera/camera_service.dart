import 'dart:async';
import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

/// Camera service for managing device camera
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  StreamController<CameraImage>? _frameStreamController;
  bool _isInitialized = false;
  bool _isStreamingFrames = false;

  final StreamController<CameraState> _stateController =
      StreamController<CameraState>.broadcast();

  final StreamController<List<CameraDescription>> _camerasController =
      StreamController<List<CameraDescription>>.broadcast();

  void _emitState(CameraState state) {
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _emitCameras(List<CameraDescription> cameras) {
    if (!_camerasController.isClosed) {
      _camerasController.add(cameras);
    }
  }

  /// Stream of camera state changes
  Stream<CameraState> get stateStream => _stateController.stream;

  /// Stream of available cameras
  Stream<List<CameraDescription>> get camerasStream => _camerasController.stream;

  /// Stream of camera frames for processing
  Stream<CameraImage>? get frameStream => _frameStreamController?.stream;

  /// Current camera controller
  CameraController? get controller => _controller;

  /// Whether camera is initialized
  bool get isInitialized => _isInitialized;

  /// Available cameras
  List<CameraDescription> get cameras => List.unmodifiable(_cameras);

  /// Current camera index
  int get currentCameraIndex => _currentCameraIndex;

  /// Current camera description
  CameraDescription? get currentCamera =>
      _cameras.isNotEmpty ? _cameras[_currentCameraIndex] : null;

  /// Initialize camera service
  Future<bool> initialize() async {
    try {
      // On Apple desktop, relying on camera plugin initialization is more
      // reliable than permission_handler pre-check.
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          _emitState(const CameraState.error('Camera permission denied'));
          return false;
        }
      }

      // Get available cameras
      _cameras = await availableCameras();
      _emitCameras(_cameras);

      if (_cameras.isEmpty) {
        _emitState(const CameraState.error('No cameras found'));
        return false;
      }

      // Try to find back camera first (for door monitoring)
      _currentCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_currentCameraIndex < 0) _currentCameraIndex = 0;

      _emitState(CameraState.ready(_cameras[_currentCameraIndex]));
      return true;
    } on CameraException catch (e) {
      _emitState(CameraState.error('Camera error (${e.code}): ${e.description ?? 'unknown error'}'));
      return false;
    } catch (e) {
      _emitState(CameraState.error(e.toString()));
      return false;
    }
  }

  /// Start camera with specific index
  Future<bool> startCamera({int? cameraIndex}) async {
    if (_cameras.isEmpty) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    // Dispose existing controller
    await stopCamera();

    // Use provided or current index
    if (cameraIndex != null &&
        cameraIndex >= 0 &&
        cameraIndex < _cameras.length) {
      _currentCameraIndex = cameraIndex;
    }

    try {
      final camera = _cameras[_currentCameraIndex];

      if (Platform.isAndroid || Platform.isIOS) {
        _controller = CameraController(
          camera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        );
      } else {
        _controller = CameraController(
          camera,
          ResolutionPreset.high,
          enableAudio: false,
        );
      }

      await _controller!.initialize();

      _isInitialized = true;
      _emitState(CameraState.active(camera));
      return true;
    } on CameraException catch (e) {
      _emitState(CameraState.error('Failed to start camera (${e.code}): ${e.description ?? 'unknown error'}'));
      return false;
    } catch (e) {
      _emitState(CameraState.error(e.toString()));
      return false;
    }
  }

  /// Start streaming frames for gesture detection
  Future<void> startFrameStream() async {
    if (_controller == null || !_isInitialized) {
      throw Exception('Camera not initialized');
    }

    if (Platform.isMacOS) {
      _emitState(const CameraState.error(
          'Real-time frame stream is not supported on macOS in this build.'));
      return;
    }

    if (_isStreamingFrames) return;

    _frameStreamController = StreamController<CameraImage>.broadcast();

    try {
      await _controller!.startImageStream((image) {
        if (_frameStreamController != null && !_frameStreamController!.isClosed) {
          _frameStreamController!.add(image);
        }
      });
      _isStreamingFrames = true;
      _emitState(const CameraState.streaming());
    } catch (e) {
      _emitState(CameraState.error('Failed to start frame stream: $e'));
    }
  }

  /// Stop streaming frames
  Future<void> stopFrameStream() async {
    if (!_isStreamingFrames) return;

    try {
      await _controller?.stopImageStream();
    } catch (e) {
      // Ignore errors when stopping
    }

    await _frameStreamController?.close();
    _frameStreamController = null;
    _isStreamingFrames = false;

    if (_isInitialized) {
      final camera = currentCamera;
      if (camera != null) {
        _emitState(CameraState.active(camera));
      }
    }
  }

  /// Stop camera
  Future<void> stopCamera() async {
    await stopFrameStream();

    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;

    final camera = currentCamera;
    if (camera != null) {
      _emitState(CameraState.ready(camera));
    }
  }

  /// Switch camera
  Future<bool> switchCamera() async {
    if (_cameras.length <= 1) return false;

    final nextIndex = (_currentCameraIndex + 1) % _cameras.length;
    return await startCamera(cameraIndex: nextIndex);
  }

  /// Set flash mode
  Future<void> setFlashMode(FlashMode mode) async {
    if (_controller == null) return;
    try {
      await _controller!.setFlashMode(mode);
    } catch (e) {
      // Flash may not be supported
    }
  }

  /// Capture image
  Future<XFile?> captureImage() async {
    if (_controller == null || !_isInitialized) return null;

    try {
      return await _controller!.takePicture();
    } catch (e) {
      return null;
    }
  }

  /// Get image size
  Size? getImageSize() {
    if (_controller == null ||
        _controller!.value.isInitialized == false) {
      return null;
    }
    return Size(
      _controller!.value.previewSize!.height,
      _controller!.value.previewSize!.width,
    );
  }

  /// Dispose resources
  void dispose() {
    unawaited(stopCamera());
    _stateController.close();
    _camerasController.close();
  }
}

/// Camera state sealed class
sealed class CameraState {
  const CameraState();

  const factory CameraState.ready(CameraDescription camera) = CameraReadyState;
  const factory CameraState.active(CameraDescription camera) = CameraActiveState;
  const factory CameraState.streaming() = CameraStreamingState;
  const factory CameraState.error(String message) = CameraErrorState;
}

class CameraReadyState extends CameraState {
  final CameraDescription camera;
  const CameraReadyState(this.camera);
}

class CameraActiveState extends CameraState {
  final CameraDescription camera;
  const CameraActiveState(this.camera);
}

class CameraStreamingState extends CameraState {
  const CameraStreamingState();
}

class CameraErrorState extends CameraState {
  final String message;
  const CameraErrorState(this.message);
}

/// Size class for camera dimensions
class Size {
  final double width;
  final double height;
  const Size(this.width, this.height);
}
