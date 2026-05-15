import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../shared/models/models.dart' as models;
import '../camera/camera_service.dart' as camera_service;

/// Gesture detection service using ML Kit Pose + Face Detection
class GestureDetector {
  final camera_service.CameraService _cameraService;

  final StreamController<models.GestureResult> _gestureController =
      StreamController<models.GestureResult>.broadcast();

  // ML Kit detectors
  PoseDetector? _poseDetector;
  FaceDetector? _faceDetector;

  // Detection state
  DateTime? _lastGestureTime;
  models.GestureType _lastGestureType = models.GestureType.unknown;
  int _consecutiveGestures = 0;
  int _frameCount = 0;

  // Wave detection state
  final List<double> _wristPositions = [];
  static const int _wavingHistoryLength = 10;
  static const double _wavingThreshold = 0.15;

  // Eyes-closed detection: track when eyes were first closed
  DateTime? _eyesClosedStartTime;
  static const Duration _eyesClosedDuration = Duration(seconds: 10);

  /// Stream of detected gestures
  Stream<models.GestureResult> get gestureStream => _gestureController.stream;

  /// Whether detection is active
  bool isDetecting = false;

  final double _minPoseConfidence;
  final double _minGestureConfidence;
  final int _debounceMs;

  GestureDetector(
    this._cameraService, {
    double minPoseConfidence = 0.5,
    double minGestureConfidence = 0.6,
    int debounceMs = 2000,
  })  : _minPoseConfidence = minPoseConfidence,
        _minGestureConfidence = minGestureConfidence,
        _debounceMs = debounceMs;

  /// Initialize the detectors
  Future<void> initialize() async {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  /// Start detecting gestures from camera stream
  Future<void> startDetection() async {
    if (isDetecting) return;
    if (_poseDetector == null || _faceDetector == null) {
      await initialize();
    }
    _cameraService.frameStream?.listen(_processFrame);
    isDetecting = true;
  }

  /// Stop detecting gestures
  Future<void> stopDetection() async {
    isDetecting = false;
    _resetDetectionState();
  }

  /// Process a single camera frame through both detectors
  Future<void> _processFrame(CameraImage cameraImage) async {
    if (!isDetecting) return;

    _frameCount++;
    if (_frameCount % 3 != 0) return;

    final inputImage = _convertCameraImage(cameraImage);
    if (inputImage == null) return;

    try {
      final results = await Future.wait([
        _processFaceFrame(inputImage),
        _processPoseFrame(inputImage),
      ]);

      final faceGesture = results[0];
      final poseGesture = results[1];

      // Prioritize eyes-closed (face), then pose gestures
      final result = faceGesture ?? poseGesture;

      if (result != null &&
          result.type != models.GestureType.unknown &&
          result.confidence >= _minGestureConfidence) {
        _handleDetectedGesture(result);
      }
    } catch (e) {
      debugPrint('Error processing frame: $e');
    }
  }

  Future<models.GestureResult?> _processFaceFrame(InputImage inputImage) async {
    if (_faceDetector == null) return null;
    try {
      final faces = await _faceDetector!.processImage(inputImage);
      if (faces.isEmpty) {
        _eyesClosedStartTime = null;
        return null;
      }
      final face = faces.first;

      final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
      final avgEyeOpen = (leftEyeOpen + rightEyeOpen) / 2;
      final areEyesClosed = avgEyeOpen < 0.5;

      if (areEyesClosed) {
        _eyesClosedStartTime ??= DateTime.now();
        if (DateTime.now().difference(_eyesClosedStartTime!) >=
            _eyesClosedDuration) {
          _eyesClosedStartTime = null;
          final confidence = 1.0 - avgEyeOpen;
          return models.GestureResult(
            type: models.GestureType.eyesClosed,
            confidence: confidence,
            timestamp: DateTime.now(),
            landmarkPositions: {},
            quality: _estimateQuality(confidence),
          );
        }
      } else {
        _eyesClosedStartTime = null;
      }
    } catch (e) {
      debugPrint('Face detection error: $e');
    }
    return null;
  }

  Future<models.GestureResult?> _processPoseFrame(InputImage inputImage) async {
    if (_poseDetector == null) return null;
    try {
      final poses = await _poseDetector!.processImage(inputImage);
      if (poses.isEmpty) return null;

      final pose = poses.first;

      double avgVisibility = 0;
      int count = 0;
      for (final lm in pose.landmarks.values) {
        avgVisibility += lm.likelihood;
        count++;
      }
      if (count > 0) avgVisibility /= count;
      if (avgVisibility < _minPoseConfidence) return null;

      final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
      final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

      if (leftWrist == null || rightWrist == null) return null;

      // 1. Tummy rub: hand near abdomen
      final tummyResult = _detectTummyRub(
        leftWrist, rightWrist, leftShoulder, rightShoulder, leftHip, rightHip,
      );
      if (tummyResult != null && tummyResult.confidence >= _minGestureConfidence) {
        return tummyResult;
      }

      // 2. Wave: wrist above shoulder with horizontal oscillation
      final waveResult = _detectWave(
        leftWrist, rightWrist, leftShoulder, rightShoulder,
      );
      if (waveResult != null && waveResult.confidence >= _minGestureConfidence) {
        return waveResult;
      }
    } catch (e) {
      debugPrint('Pose detection error: $e');
    }
    return null;
  }

  models.GestureResult? _detectWave(
    PoseLandmark leftWrist,
    PoseLandmark rightWrist,
    PoseLandmark? leftShoulder,
    PoseLandmark? rightShoulder,
  ) {
    final PoseLandmark activeWrist;
    final PoseLandmark? referenceShoulder;

    if (leftWrist.likelihood >= rightWrist.likelihood) {
      activeWrist = leftWrist;
      referenceShoulder = leftShoulder;
    } else {
      activeWrist = rightWrist;
      referenceShoulder = rightShoulder;
    }

    if (referenceShoulder == null) return null;

    // Wrist must be above shoulder
    if (activeWrist.y >= referenceShoulder.y - 0.05) {
      _wristPositions.clear();
      return null;
    }

    _wristPositions.add(activeWrist.x);
    if (_wristPositions.length > _wavingHistoryLength) {
      _wristPositions.removeAt(0);
    }

    if (_wristPositions.length < _wavingHistoryLength) return null;

    final minX = _wristPositions.reduce(math.min);
    final maxX = _wristPositions.reduce(math.max);
    final range = maxX - minX;

    if (range < _wavingThreshold) return null;

    final confidence = activeWrist.likelihood *
        (range / _wavingThreshold).clamp(0.0, 1.0);
    return models.GestureResult(
      type: models.GestureType.wave,
      confidence: confidence,
      timestamp: DateTime.now(),
      landmarkPositions: {},
      quality: _estimateQuality(confidence),
    );
  }

  models.GestureResult? _detectTummyRub(
    PoseLandmark leftWrist,
    PoseLandmark rightWrist,
    PoseLandmark? leftShoulder,
    PoseLandmark? rightShoulder,
    PoseLandmark? leftHip,
    PoseLandmark? rightHip,
  ) {
    if (leftHip == null || rightHip == null) return null;
    if (leftShoulder == null || rightShoulder == null) return null;

    final abdomenTop = (leftShoulder.y + rightShoulder.y) / 2;
    final abdomenBottom = (leftHip.y + rightHip.y) / 2;
    final abdomenCenterX = (leftHip.x + rightHip.x) / 2;

    final leftOnTummy = leftWrist.y > abdomenTop + 0.05 &&
        leftWrist.y < abdomenBottom &&
        (leftWrist.x - abdomenCenterX).abs() < 0.25;

    final rightOnTummy = rightWrist.y > abdomenTop + 0.05 &&
        rightWrist.y < abdomenBottom &&
        (rightWrist.x - abdomenCenterX).abs() < 0.25;

    if (!leftOnTummy && !rightOnTummy) return null;

    final confidence =
        leftOnTummy ? leftWrist.likelihood : rightWrist.likelihood;

    return models.GestureResult(
      type: models.GestureType.tummyRub,
      confidence: confidence,
      timestamp: DateTime.now(),
      landmarkPositions: {},
      quality: _estimateQuality(confidence),
    );
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera = _cameraService.currentCamera;
      final rotation = InputImageRotationValue.fromRawValue(
            camera?.sensorOrientation ?? 90,
          ) ??
          InputImageRotation.rotation0deg;

      final imageFormat = InputImageFormatValue.fromRawValue(image.format.raw);
      final bytes = _imageBytes(image, imageFormat);
      if (bytes == null || image.planes.isEmpty) return null;

      final metadata = InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: imageFormat ?? InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('Error converting image: $e');
      return null;
    }
  }

  Uint8List? _imageBytes(CameraImage image, InputImageFormat? format) {
    if (image.planes.isEmpty) return null;
    if (format == InputImageFormat.bgra8888 ||
        format == InputImageFormat.nv21) {
      return image.planes.first.bytes;
    }
    return _concatenatePlanes(image);
  }

  Uint8List _concatenatePlanes(CameraImage image) {
    final totalBytes = image.planes.fold<int>(
      0,
      (sum, plane) => sum + plane.bytes.length,
    );
    final result = Uint8List(totalBytes);
    int offset = 0;
    for (final plane in image.planes) {
      result.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return result;
  }

  void _handleDetectedGesture(models.GestureResult result) {
    final now = DateTime.now();

    if (_lastGestureTime != null &&
        now.difference(_lastGestureTime!).inMilliseconds < _debounceMs &&
        result.type == _lastGestureType) {
      return;
    }

    if (result.type == _lastGestureType) {
      _consecutiveGestures++;
    } else {
      _consecutiveGestures = 0;
      _lastGestureType = result.type;
    }

    if (_consecutiveGestures >= 2) {
      _gestureController.add(result);
      _lastGestureTime = now;
      _consecutiveGestures = 0;
    }
  }

  models.DetectionQuality _estimateQuality(double visibility) {
    if (visibility >= 0.9) return models.DetectionQuality.excellent;
    if (visibility >= 0.75) return models.DetectionQuality.good;
    if (visibility >= 0.5) return models.DetectionQuality.fair;
    return models.DetectionQuality.poor;
  }

  void _resetDetectionState() {
    _wristPositions.clear();
    _consecutiveGestures = 0;
    _lastGestureType = models.GestureType.unknown;
    _eyesClosedStartTime = null;
  }

  Future<void> dispose() async {
    await stopDetection();
    await _poseDetector?.close();
    await _faceDetector?.close();
    await _gestureController.close();
  }
}
