import 'dart:convert';
import 'package:flutter/material.dart';

/// Gesture type enum for gesture detection
enum GestureType {
  wave,
  eyesClosed,
  tummyRub,
  unknown,
}

/// Gesture detection result model
class GestureResult {
  final GestureType type;
  final double confidence;
  final DateTime timestamp;
  final Map<String, double> landmarkPositions;
  final DetectionQuality quality;

  const GestureResult({
    required this.type,
    required this.confidence,
    required this.timestamp,
    required this.landmarkPositions,
    required this.quality,
  });

  GestureResult copyWith({
    GestureType? type,
    double? confidence,
    DateTime? timestamp,
    Map<String, double>? landmarkPositions,
    DetectionQuality? quality,
  }) {
    return GestureResult(
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      landmarkPositions: landmarkPositions ?? this.landmarkPositions,
      quality: quality ?? this.quality,
    );
  }

  String get displayLabel => '${type.displayName} (${(confidence * 100).toInt()}%)';

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
        'landmarkPositions': landmarkPositions,
        'quality': quality.name,
      };

  factory GestureResult.fromJson(Map<String, dynamic> json) => GestureResult(
        type: GestureType.values.firstWhere((e) => e.name == json['type']),
        confidence: (json['confidence'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp']),
        landmarkPositions: Map<String, double>.from(json['landmarkPositions']),
        quality: DetectionQuality.values.firstWhere((e) => e.name == json['quality']),
      );
}

/// Home Assistant entity model
class HaEntity {
  final String entityId;
  final String name;
  final String domain;
  final String state;
  final Map<String, dynamic>? attributes;
  final DateTime lastChanged;
  final DateTime lastUpdated;

  const HaEntity({
    required this.entityId,
    required this.name,
    required this.domain,
    required this.state,
    this.attributes,
    required this.lastChanged,
    required this.lastUpdated,
  });

  bool get isLock => domain == 'lock';
  LockState get lockState {
    if (!isLock) return LockState.unknown;
    switch (state.toLowerCase()) {
      case 'locked':
        return LockState.locked;
      case 'unlocked':
        return LockState.unlocked;
      case 'jammed':
        return LockState.jammed;
      default:
        return LockState.unknown;
    }
  }

  String get friendlyName => attributes?['friendly_name'] as String? ?? name;

  Map<String, dynamic> toJson() => {
        'entityId': entityId,
        'name': name,
        'domain': domain,
        'state': state,
        'attributes': attributes,
        'lastChanged': lastChanged.toIso8601String(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory HaEntity.fromJson(Map<String, dynamic> json) => HaEntity(
        entityId: json['entityId'] as String,
        name: json['name'] as String,
        domain: json['domain'] as String,
        state: json['state'] as String,
        attributes: json['attributes'] as Map<String, dynamic>?,
        lastChanged: DateTime.parse(json['lastChanged'] as String),
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      );
}

/// Alert model for notifications
class Alert {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool acknowledged;
  final bool dismissed;

  const Alert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.acknowledged = false,
    this.dismissed = false,
  });

  Alert copyWith({
    String? id,
    AlertType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? acknowledged,
    bool? dismissed,
  }) {
    return Alert(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      acknowledged: acknowledged ?? this.acknowledged,
      dismissed: dismissed ?? this.dismissed,
    );
  }

  String get timeAgo => _getTimeAgo(timestamp);

  static String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'acknowledged': acknowledged,
        'dismissed': dismissed,
      };

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as String,
        type: AlertType.values.firstWhere((e) => e.name == json['type']),
        title: json['title'] as String,
        message: json['message'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        acknowledged: json['acknowledged'] as bool? ?? false,
        dismissed: json['dismissed'] as bool? ?? false,
      );
}

/// Activity log entry for research data
class ActivityLog {
  final String id;
  final DateTime timestamp;
  final ActivityEventType eventType;
  final String? description;
  final double? confidence;
  final Map<String, dynamic>? metadata;
  final bool isUserAction;

  const ActivityLog({
    required this.id,
    required this.timestamp,
    required this.eventType,
    this.description,
    this.confidence,
    this.metadata,
    this.isUserAction = false,
  });

  ActivityLog copyWith({
    String? id,
    DateTime? timestamp,
    ActivityEventType? eventType,
    String? description,
    double? confidence,
    Map<String, dynamic>? metadata,
    bool? isUserAction,
  }) {
    return ActivityLog(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      eventType: eventType ?? this.eventType,
      description: description ?? this.description,
      confidence: confidence ?? this.confidence,
      metadata: metadata ?? this.metadata,
      isUserAction: isUserAction ?? this.isUserAction,
    );
  }

  String get eventDescription => description ?? eventType.displayName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'eventType': eventType.name,
        'description': description,
        'confidence': confidence,
        'metadata': metadata,
        'isUserAction': isUserAction,
      };

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        eventType: ActivityEventType.values.firstWhere((e) => e.name == json['eventType']),
        description: json['description'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
        metadata: json['metadata'] as Map<String, dynamic>?,
        isUserAction: json['isUserAction'] as bool? ?? false,
      );
}

/// User settings model
class UserSettings {
  final String? haUrl;
  final String? haToken;
  final String? selectedLockEntity;
  final bool notificationsEnabled;
  final int sensitivity;
  final bool monitoringEnabled;
  final int alertTimeout;
  final Map<String, dynamic>? doorHandleCalibration;

  const UserSettings({
    this.haUrl,
    this.haToken,
    this.selectedLockEntity,
    this.notificationsEnabled = true,
    this.sensitivity = 50,
    this.monitoringEnabled = false,
    this.alertTimeout = 5,
    this.doorHandleCalibration,
  });

  UserSettings copyWith({
    String? haUrl,
    String? haToken,
    String? selectedLockEntity,
    bool? notificationsEnabled,
    int? sensitivity,
    bool? monitoringEnabled,
    int? alertTimeout,
    Map<String, dynamic>? doorHandleCalibration,
  }) {
    return UserSettings(
      haUrl: haUrl ?? this.haUrl,
      haToken: haToken ?? this.haToken,
      selectedLockEntity: selectedLockEntity ?? this.selectedLockEntity,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      sensitivity: sensitivity ?? this.sensitivity,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      alertTimeout: alertTimeout ?? this.alertTimeout,
      doorHandleCalibration: doorHandleCalibration ?? this.doorHandleCalibration,
    );
  }

  bool get isHaConfigured => haUrl != null && haToken != null && haUrl!.isNotEmpty;
}

/// Detection quality enum
enum DetectionQuality {
  excellent,
  good,
  fair,
  poor,
}

/// Alert type enum
enum AlertType {
  doorLeftUnlocked,
  lockStateChanged,
  connectionLost,
  gestureDetected,
  systemError,
}

/// Activity event type enum
enum ActivityEventType {
  gestureDetected,
  lockStateChanged,
  alertTriggered,
  alertAcknowledged,
  monitoringStarted,
  monitoringStopped,
  haConnected,
  haDisconnected,
  settingsChanged,
  doorClose,
  leaving,
}

/// Lock state enum
enum LockState {
  locked,
  unlocked,
  unknown,
  jammed,
}

/// Lock event type enum (for lock controller events)
enum LockEventType {
  stateChanged,
  locked,
  unlocked,
  monitoringStarted,
  monitoringStopped,
}

/// Extension methods for enums
extension AlertTypeExtension on AlertType {
  String get displayName {
    switch (this) {
      case AlertType.doorLeftUnlocked:
        return 'Door Left Unlocked';
      case AlertType.lockStateChanged:
        return 'Lock State Changed';
      case AlertType.connectionLost:
        return 'Connection Lost';
      case AlertType.gestureDetected:
        return 'Gesture Detected';
      case AlertType.systemError:
        return 'System Error';
    }
  }
}

extension ActivityEventTypeExtension on ActivityEventType {
  String get displayName {
    switch (this) {
      case ActivityEventType.gestureDetected:
        return 'Gesture Detected';
      case ActivityEventType.lockStateChanged:
        return 'Lock State Changed';
      case ActivityEventType.alertTriggered:
        return 'Alert Triggered';
      case ActivityEventType.alertAcknowledged:
        return 'Alert Acknowledged';
      case ActivityEventType.monitoringStarted:
        return 'Monitoring Started';
      case ActivityEventType.monitoringStopped:
        return 'Monitoring Stopped';
      case ActivityEventType.haConnected:
        return 'Connected to Home Assistant';
      case ActivityEventType.haDisconnected:
        return 'Disconnected from Home Assistant';
      case ActivityEventType.settingsChanged:
        return 'Settings Changed';
      case ActivityEventType.doorClose:
        return 'Door Closed';
      case ActivityEventType.leaving:
        return 'Leaving Detected';
    }
  }
}

extension GestureTypeExtension on GestureType {
  String get displayName {
    switch (this) {
      case GestureType.wave:
        return 'Wave';
      case GestureType.eyesClosed:
        return 'Eyes Closed';
      case GestureType.tummyRub:
        return 'Tummy Rub';
      case GestureType.unknown:
        return 'Unknown';
    }
  }

  IconData get icon {
    switch (this) {
      case GestureType.wave:
        return Icons.waving_hand;
      case GestureType.eyesClosed:
        return Icons.visibility_off;
      case GestureType.tummyRub:
        return Icons.pregnant_woman;
      case GestureType.unknown:
        return Icons.help_outline;
    }
  }

  String get description {
    switch (this) {
      case GestureType.wave:
        return 'Raise hand above shoulder to toggle music';
      case GestureType.eyesClosed:
        return 'Close eyes for 10s to turn off main light';
      case GestureType.tummyRub:
        return 'Hand on stomach to toggle kitchen light';
      case GestureType.unknown:
        return 'Unknown gesture';
    }
  }
}

extension DetectionQualityExtension on DetectionQuality {
  String get displayName {
    switch (this) {
      case DetectionQuality.excellent:
        return 'Excellent';
      case DetectionQuality.good:
        return 'Good';
      case DetectionQuality.fair:
        return 'Fair';
      case DetectionQuality.poor:
        return 'Poor';
    }
  }
}

extension LockStateExtension on LockState {
  String get displayName {
    switch (this) {
      case LockState.locked:
        return 'Locked';
      case LockState.unlocked:
        return 'Unlocked';
      case LockState.unknown:
        return 'Unknown';
      case LockState.jammed:
        return 'Jammed';
    }
  }

  String get iconName {
    switch (this) {
      case LockState.locked:
        return 'lock';
      case LockState.unlocked:
        return 'lock_open';
      case LockState.unknown:
        return 'help';
      case LockState.jammed:
        return 'error';
    }
  }

  bool get isSecure => this == LockState.locked;
}
