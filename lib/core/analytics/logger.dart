import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, FileMode;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory;
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/models.dart' as models;
import '../../core/config/app_constants.dart';

/// Research data logger for conference paper metrics
class ResearchLogger {
  static final ResearchLogger _instance = ResearchLogger._internal();
  factory ResearchLogger() => _instance;
  ResearchLogger._internal();

  final List<models.ActivityLog> _logs = [];
  File? _logFile;
  bool _enabled = true;
  Timer? _flushTimer;
  final String _webStorageKey = 'activity_logs';

  /// Recent logs
  List<models.ActivityLog> get recentLogs => List.unmodifiable(_logs.take(100));

  /// All logs
  List<models.ActivityLog> get allLogs => List.unmodifiable(_logs);

  /// Initialize logger
  Future<void> initialize() async {
    if (kIsWeb) {
      // Load from web storage
      await _loadLogsFromWeb();
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      _logFile = File('${appDir.path}/${AppConstants.logFileName}');
      // Load existing logs
      await _loadLogs();
    }

    // Start periodic flush
    _flushTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      flush();
    });
  }

  /// Load existing logs from file
  Future<void> _loadLogs() async {
    if (_logFile == null || !await _logFile!.exists()) return;

    try {
      final lines = await _logFile!.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          _logs.add(models.ActivityLog.fromJson(json));
        } catch (_) {
          // Skip invalid lines
        }
      }
    } catch (_) {
      // File might be corrupt, start fresh
    }
  }

  /// Load existing logs from web storage
  Future<void> _loadLogsFromWeb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedLogs = prefs.getString(_webStorageKey);
      if (storedLogs != null) {
        final jsonList = jsonDecode(storedLogs) as List;
        for (final json in jsonList) {
          if (json is Map<String, dynamic>) {
            try {
              _logs.add(models.ActivityLog.fromJson(json));
            } catch (_) {
              // Skip invalid entries
            }
          }
        }
      }
    } catch (_) {
      // Storage might be corrupt, start fresh
    }
  }

  /// Log an event
  Future<void> logEvent({
    required models.ActivityEventType eventType,
    String? description,
    double? confidence,
    Map<String, dynamic>? metadata,
    bool isUserAction = false,
  }) async {
    if (!_enabled) return;

    final log = models.ActivityLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      eventType: eventType,
      description: description,
      confidence: confidence,
      metadata: metadata,
      isUserAction: isUserAction,
    );

    _logs.add(log);

    // Add to persistent storage
    await _appendToLog(log);

    // Keep in-memory limit
    if (_logs.length > 10000) {
      _logs.removeRange(0, _logs.length - 10000);
    }
  }

  /// Log gesture detection
  Future<void> logGestureDetection({
    required models.GestureType gestureType,
    required double confidence,
    models.DetectionQuality? quality,
    Map<String, double>? landmarks,
  }) async {
    await logEvent(
      eventType: models.ActivityEventType.gestureDetected,
      description: '${gestureType.displayName} (${(confidence * 100).toInt()}%)',
      confidence: confidence,
      metadata: {
        'gesture_type': gestureType.name,
        'quality': quality?.name,
        if (landmarks != null) 'landmarks': landmarks,
      },
    );
  }

  /// Log lock state change
  Future<void> logLockStateChange({
    required models.LockState oldState,
    required models.LockState newState,
    String? entityId,
    bool automated = false,
  }) async {
    await logEvent(
      eventType: models.ActivityEventType.lockStateChanged,
      description: 'Lock: ${oldState.displayName} → ${newState.displayName}',
      metadata: {
        'old_state': oldState.name,
        'new_state': newState.name,
        'entity_id': entityId,
        'automated': automated,
      },
    );
  }

  /// Log alert triggered
  Future<void> logAlertTriggered({
    required models.AlertType alertType,
    String? lockName,
    Duration? timeUnlocked,
  }) async {
    await logEvent(
      eventType: models.ActivityEventType.alertTriggered,
      description: 'Alert: ${alertType.displayName}',
      metadata: {
        'alert_type': alertType.name,
        'lock_name': lockName,
        'time_unlocked_seconds': timeUnlocked?.inSeconds,
      },
    );
  }

  /// Log alert acknowledged
  Future<void> logAlertAcknowledged({
    required String alertId,
    String? action,
  }) async {
    await logEvent(
      eventType: models.ActivityEventType.alertAcknowledged,
      description: 'Alert acknowledged: ${action ?? "dismissed"}',
      metadata: {
        'alert_id': alertId,
        'action': action,
      },
      isUserAction: true,
    );
  }

  /// Log monitoring state change
  Future<void> logMonitoringChange({
    required bool started,
  }) async {
    await logEvent(
      eventType: started
          ? models.ActivityEventType.monitoringStarted
          : models.ActivityEventType.monitoringStopped,
      description: started ? 'Monitoring started' : 'Monitoring stopped',
      isUserAction: true,
    );
  }

  /// Log Home Assistant connection
  Future<void> logConnection({
    required bool connected,
    String? url,
  }) async {
    await logEvent(
      eventType: connected
          ? models.ActivityEventType.haConnected
          : models.ActivityEventType.haDisconnected,
      description: connected
          ? 'Connected to Home Assistant'
          : 'Disconnected from Home Assistant',
      metadata: {'url': url},
    );
  }

  /// Log settings change
  Future<void> logSettingsChange({
    required String setting,
    required dynamic oldValue,
    required dynamic newValue,
  }) async {
    await logEvent(
      eventType: models.ActivityEventType.settingsChanged,
      description: 'Setting changed: $setting',
      metadata: {
        'setting': setting,
        'old_value': oldValue,
        'new_value': newValue,
      },
      isUserAction: true,
    );
  }

  /// Append log to file
  Future<void> _appendToLog(models.ActivityLog log) async {
    if (kIsWeb) {
      await _appendToWebLog(log);
    } else {
      if (_logFile == null) return;

      try {
        final json = jsonEncode(log.toJson());
        await _logFile!.writeAsString('$json\n', mode: FileMode.append, flush: false);

        // Check file size
        final stat = await _logFile!.stat();
        if (stat.size > AppConstants.maxLogFileSize) {
          await _rotateLog();
        }
      } catch (_) {
        // Silent fail for logging errors
      }
    }
  }

  /// Append log to web storage
  Future<void> _appendToWebLog(models.ActivityLog log) async {
    try {
      _logs.add(log);
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _logs.map((l) => l.toJson()).toList();
      await prefs.setString(_webStorageKey, jsonEncode(jsonList));
    } catch (_) {
      // Silent fail for logging errors
    }
  }

  /// Rotate log file
  Future<void> _rotateLog() async {
    if (kIsWeb) {
      // On web, just truncate if too many logs
      if (_logs.length > 10000) {
        _logs.removeRange(0, _logs.length - 10000);
      }
      return;
    }

    if (_logFile == null) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();

      // Find existing rotated logs
      final rotatedLogs = <File>[];
      for (int i = 1; i <= AppConstants.maxLogFiles; i++) {
        final file = File('${appDir.path}/${AppConstants.logFileName}.$i');
        if (await file.exists()) {
          rotatedLogs.add(file);
        }
      }

      // Delete oldest if needed
      if (rotatedLogs.length >= AppConstants.maxLogFiles) {
        await rotatedLogs.first.delete();
      }

      // Shift existing logs
      for (int i = rotatedLogs.length - 1; i >= 0; i--) {
        await rotatedLogs[i].rename(
          '${appDir.path}/${AppConstants.logFileName}.${i + 2}',
        );
      }

      // Rename current log
      await _logFile!.rename(
        '${appDir.path}/${AppConstants.logFileName}.1',
      );

      // Create new log file
      _logFile = File('${appDir.path}/${AppConstants.logFileName}');
    } catch (_) {
      // If rotation fails, just truncate
      await _logFile!.writeAsString('');
    }
  }

  /// Flush pending writes
  Future<void> flush() async {
    // File writes are already flushed in _appendToLog
  }

  /// Get logs filtered by type
  List<models.ActivityLog> getLogsByType(models.ActivityEventType type) {
    return _logs.where((log) => log.eventType == type).toList();
  }

  /// Get logs in time range
  List<models.ActivityLog> getLogsInRange(DateTime start, DateTime end) {
    return _logs.where((log) {
      return log.timestamp.isAfter(start) && log.timestamp.isBefore(end);
    }).toList();
  }

  /// Get today's logs
  List<models.ActivityLog> getTodayLogs() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return getLogsInRange(startOfDay, now);
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    _logs.clear();
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_webStorageKey);
    } else {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }
    }
  }

  /// Export logs as JSON string
  String exportAsJson() {
    final jsonList = _logs.map((log) => log.toJson()).toList();
    return jsonEncode(jsonList);
  }

  /// Export logs as CSV string
  String exportAsCsv() {
    final buffer = StringBuffer();
    buffer.writeln('timestamp,event_type,description,confidence,metadata');

    for (final log in _logs) {
      buffer.writeln(
        '${log.timestamp.toIso8601String()},'
        '${log.eventType.name},'
        '${log.description?.replaceAll(',', ';')},'
        '${log.confidence?.toStringAsFixed(3) ?? ''},'
        '${jsonEncode(log.metadata).replaceAll(',', ';')}',
      );
    }

    return buffer.toString();
  }

  /// Enable or disable logging
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await flush();
    _flushTimer?.cancel();
  }
}

/// Metrics calculator for research data
class MetricsCalculator {
  final List<models.ActivityLog> logs;

  MetricsCalculator(this.logs);

  /// Calculate gesture detection accuracy
  DetectionMetrics calculateGestureMetrics() {
    final gestureLogs = logs
        .where((l) => l.eventType == models.ActivityEventType.gestureDetected)
        .toList();

    if (gestureLogs.isEmpty) {
      return const DetectionMetrics(
        totalDetections: 0,
        truePositives: 0,
        falsePositives: 0,
        accuracy: 0,
        averageConfidence: 0,
      );
    }

    // For research, true positives would need user confirmation
    // This is a placeholder that assumes high confidence = true positive
    final truePositives = gestureLogs
        .where((l) => (l.confidence ?? 0) > 0.8)
        .length;

    final falsePositives = gestureLogs.length - truePositives;

    double totalConfidence = 0;
    for (final log in gestureLogs) {
      totalConfidence += log.confidence ?? 0;
    }

    return DetectionMetrics(
      totalDetections: gestureLogs.length,
      truePositives: truePositives,
      falsePositives: falsePositives,
      accuracy: gestureLogs.isNotEmpty
          ? truePositives / gestureLogs.length
          : 0,
      averageConfidence: gestureLogs.isNotEmpty
          ? totalConfidence / gestureLogs.length
          : 0,
    );
  }

  /// Calculate alert metrics
  AlertMetrics calculateAlertMetrics() {
    final alertLogs = logs
        .where((l) => l.eventType == models.ActivityEventType.alertTriggered)
        .toList();

    final acknowledgedLogs = logs
        .where((l) => l.eventType == models.ActivityEventType.alertAcknowledged)
        .length;

    return AlertMetrics(
      totalAlerts: alertLogs.length,
      acknowledgedAlerts: acknowledgedLogs,
      acknowledgmentRate: alertLogs.isNotEmpty
          ? acknowledgedLogs / alertLogs.length
          : 0,
    );
  }

  /// Get usage statistics
  UsageStats getUsageStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayLogs = logs.where((l) => l.timestamp.isAfter(today)).toList();
    final userActions = todayLogs.where((l) => l.isUserAction).length;

    // Calculate session duration (time between first and last log today)
    DateTime? firstLog;
    DateTime? lastLog;
    for (final log in todayLogs) {
      firstLog ??= log.timestamp;
      lastLog = log.timestamp;
    }

    final sessionDuration = (firstLog != null && lastLog != null)
        ? lastLog.difference(firstLog)
        : Duration.zero;

    return UsageStats(
      totalEvents: todayLogs.length,
      userActions: userActions,
      sessionDuration: sessionDuration,
    );
  }
}

/// Detection metrics
class DetectionMetrics {
  final int totalDetections;
  final int truePositives;
  final int falsePositives;
  final double accuracy;
  final double averageConfidence;

  const DetectionMetrics({
    required this.totalDetections,
    required this.truePositives,
    required this.falsePositives,
    required this.accuracy,
    required this.averageConfidence,
  });

  double get precision =>
      (truePositives + falsePositives) > 0
          ? truePositives / (truePositives + falsePositives)
          : 0;

  double get recall => totalDetections > 0 ? truePositives / totalDetections : 0;

  double get f1Score =>
      (precision + recall) > 0
          ? 2 * (precision * recall) / (precision + recall)
          : 0;
}

/// Alert metrics
class AlertMetrics {
  final int totalAlerts;
  final int acknowledgedAlerts;
  final double acknowledgmentRate;

  const AlertMetrics({
    required this.totalAlerts,
    required this.acknowledgedAlerts,
    required this.acknowledgmentRate,
  });
}

/// Usage statistics
class UsageStats {
  final int totalEvents;
  final int userActions;
  final Duration sessionDuration;

  const UsageStats({
    required this.totalEvents,
    required this.userActions,
    required this.sessionDuration,
  });
}
