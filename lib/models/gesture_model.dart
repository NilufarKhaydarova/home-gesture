import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Gesture type enum
enum GestureType {
  openHand,
  closedFist,
  pointing,
  thumbsUp,
  peaceSign,
  unknown,
}

/// Extension methods for GestureType
extension GestureTypeExtension on GestureType {
  String get displayName {
    switch (this) {
      case GestureType.openHand:
        return 'Open Hand';
      case GestureType.closedFist:
        return 'Closed Fist';
      case GestureType.pointing:
        return 'Pointing';
      case GestureType.thumbsUp:
        return 'Thumbs Up';
      case GestureType.peaceSign:
        return 'Peace Sign';
      case GestureType.unknown:
        return 'Unknown';
    }
  }

  IconData get icon {
    switch (this) {
      case GestureType.openHand:
        return Icons.back_hand;
      case GestureType.closedFist:
        return Icons.pan_tool;
      case GestureType.pointing:
        return Icons.ads_click;
      case GestureType.thumbsUp:
        return Icons.thumb_up;
      case GestureType.peaceSign:
        return Icons.emoji_people;
      case GestureType.unknown:
        return Icons.help_outline;
    }
  }

  String get description {
    switch (this) {
      case GestureType.openHand:
        return 'All fingers extended';
      case GestureType.closedFist:
        return 'All fingers curled';
      case GestureType.pointing:
        return 'Index finger extended';
      case GestureType.thumbsUp:
        return 'Thumb extended upward';
      case GestureType.peaceSign:
        return 'Index and middle fingers extended';
      case GestureType.unknown:
        return 'No gesture detected';
    }
  }

  Color get color {
    switch (this) {
      case GestureType.openHand:
        return const Color(0xFF10B981);
      case GestureType.closedFist:
        return const Color(0xFFF59E0B);
      case GestureType.pointing:
        return const Color(0xFF3B82F6);
      case GestureType.thumbsUp:
        return const Color(0xFF8B5CF6);
      case GestureType.peaceSign:
        return const Color(0xFFEC4899);
      case GestureType.unknown:
        return const Color(0xFF6B7280);
    }
  }
}

/// Gesture detection result model
class GestureResult {
  final GestureType type;
  final double confidence;
  final DateTime timestamp;
  final Map<String, double> landmarkPositions;

  const GestureResult({
    required this.type,
    required this.confidence,
    required this.timestamp,
    this.landmarkPositions = const {},
  });

  String get displayLabel => '${type.displayName} (${(confidence * 100).toInt()}%)';

  GestureResult copyWith({
    GestureType? type,
    double? confidence,
    DateTime? timestamp,
    Map<String, double>? landmarkPositions,
  }) {
    return GestureResult(
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      landmarkPositions: landmarkPositions ?? this.landmarkPositions,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
        'landmarkPositions': landmarkPositions,
      };

  factory GestureResult.fromJson(Map<String, dynamic> json) => GestureResult(
        type: GestureType.values.firstWhere((e) => e.name == json['type']),
        confidence: (json['confidence'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp']),
        landmarkPositions:
            Map<String, double>.from(json['landmarkPositions'] ?? {}),
      );
}