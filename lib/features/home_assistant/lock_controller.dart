import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../shared/models/models.dart' as models;
import '../../core/config/app_constants.dart';
import 'ha_service.dart';

/// Controller for managing smart lock entities
class LockController {
  final HomeAssistantService _haService;

  models.HaEntity? _selectedLock;
  models.LockState _currentState = models.LockState.unknown;
  DateTime? _lastStateChange;
  bool _isMonitoring = false;

  final StreamController<models.LockState> _stateController =
      StreamController<models.LockState>.broadcast();

  final StreamController<LockEvent> _eventController =
      StreamController<LockEvent>.broadcast();

  StreamSubscription? _haSubscription;

  /// Stream of lock state changes
  Stream<models.LockState> get stateStream => _stateController.stream;

  /// Stream of lock events
  Stream<LockEvent> get eventStream => _eventController.stream;

  /// Current selected lock entity
  models.HaEntity? get selectedLock => _selectedLock;

  /// Current lock state
  models.LockState get currentState => _currentState;

  /// Time of last state change
  DateTime? get lastStateChange => _lastStateChange;

  /// Whether monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Whether lock is currently secure
  bool get isSecure => _currentState == models.LockState.locked;

  LockController(this._haService) {
    _listenToHaUpdates();
  }

  /// Set the lock entity to control
  void setSelectedLock(String? entityId) {
    if (entityId == null) {
      _selectedLock = null;
      _currentState = models.LockState.unknown;
      return;
    }

    final locks = _haService.getLockEntities();
    _selectedLock = locks.firstWhere(
      (l) => l.entityId == entityId,
      orElse: () => locks.first,
    );

    if (_selectedLock != null) {
      _updateState(_selectedLock!.lockState);
    }
  }

  /// Listen to Home Assistant entity updates
  void _listenToHaUpdates() {
    _haSubscription = _haService.entityUpdateStream.listen((entity) {
      if (_selectedLock != null &&
          entity.entityId == _selectedLock!.entityId) {
        final newState = entity.lockState;
        if (newState != _currentState) {
          _updateState(newState);
          _eventController.add(LockEvent(
            type: LockEventType.stateChanged,
            oldState: _currentState,
            newState: newState,
            timestamp: DateTime.now(),
          ));
        }
      }
    });
  }

  /// Update current state
  void _updateState(models.LockState newState) {
    if (newState != _currentState) {
      _currentState = newState;
      _lastStateChange = DateTime.now();
      _stateController.add(newState);
    }
  }

  /// Start monitoring the lock
  void startMonitoring() {
    _isMonitoring = true;
    _eventController.add(LockEvent(
      type: LockEventType.monitoringStarted,
      oldState: _currentState,
      newState: _currentState,
      timestamp: DateTime.now(),
    ));
  }

  /// Stop monitoring the lock
  void stopMonitoring() {
    _isMonitoring = false;
    _eventController.add(LockEvent(
      type: LockEventType.monitoringStopped,
      oldState: _currentState,
      newState: _currentState,
      timestamp: DateTime.now(),
    ));
  }

  /// Lock the door via Home Assistant
  Future<LockResult> lock() async {
    if (_selectedLock == null) {
      return LockResult.failure('No lock selected');
    }

    if (!_haService.isConnected) {
      return LockResult.failure('Not connected to Home Assistant');
    }

    try {
      final success = await _haService.lockEntity(_selectedLock!.entityId);
      if (success) {
        _updateState(models.LockState.locked);
        _eventController.add(LockEvent(
          type: LockEventType.locked,
          oldState: _currentState,
          newState: models.LockState.locked,
          timestamp: DateTime.now(),
        ));
        return LockResult.success();
      }
      return LockResult.failure('Failed to send lock command');
    } catch (e) {
      return LockResult.failure('Error: $e');
    }
  }

  /// Unlock the door via Home Assistant
  Future<LockResult> unlock() async {
    if (_selectedLock == null) {
      return LockResult.failure('No lock selected');
    }

    if (!_haService.isConnected) {
      return LockResult.failure('Not connected to Home Assistant');
    }

    try {
      final success = await _haService.unlockEntity(_selectedLock!.entityId);
      if (success) {
        _updateState(models.LockState.unlocked);
        _eventController.add(LockEvent(
          type: LockEventType.unlocked,
          oldState: _currentState,
          newState: models.LockState.unlocked,
          timestamp: DateTime.now(),
        ));
        return LockResult.success();
      }
      return LockResult.failure('Failed to send unlock command');
    } catch (e) {
      return LockResult.failure('Error: $e');
    }
  }

  /// Refresh current lock state from Home Assistant
  Future<bool> refreshState() async {
    if (_selectedLock == null) return false;

    try {
      final entity = await _haService.getEntityState(_selectedLock!.entityId);
      if (entity != null) {
        _updateState(entity.lockState);
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing lock state: $e');
      }
    }
    return false;
  }

  /// Check if lock was left unlocked after a timeout
  Future<bool> checkLockAfterTimeout() async {
    await refreshState();
    return !isSecure;
  }

  /// Get available lock entities
  List<models.HaEntity> getAvailableLocks() {
    return _haService.getLockEntities();
  }

  /// Get status message
  String get statusMessage {
    if (_selectedLock == null) {
      return 'No lock configured';
    }

    switch (_currentState) {
      case models.LockState.locked:
        return '${_selectedLock!.friendlyName} is locked';
      case models.LockState.unlocked:
        return '${_selectedLock!.friendlyName} is unlocked';
      case models.LockState.jammed:
        return '${_selectedLock!.friendlyName} is jammed';
      case models.LockState.unknown:
        return '${_selectedLock!.friendlyName} status unknown';
    }
  }

  /// Get time since last state change
  Duration? getTimeSinceStateChange() {
    if (_lastStateChange == null) return null;
    return DateTime.now().difference(_lastStateChange!);
  }

  /// Dispose resources
  void dispose() async {
    await _haSubscription?.cancel();
    await _stateController.close();
    await _eventController.close();
  }
}

/// Lock event for tracking actions
class LockEvent {
  final LockEventType type;
  final models.LockState oldState;
  final models.LockState newState;
  final DateTime timestamp;

  const LockEvent({
    required this.type,
    required this.oldState,
    required this.newState,
    required this.timestamp,
  });
}

/// Lock event type
enum LockEventType {
  stateChanged,
  locked,
  unlocked,
  monitoringStarted,
  monitoringStopped,
}

/// Lock operation result
class LockResult {
  final bool success;
  final String? errorMessage;

  const LockResult._({
    required this.success,
    this.errorMessage,
  });

  factory LockResult.success() {
    return const LockResult._(success: true);
  }

  factory LockResult.failure(String error) {
    return LockResult._(success: false, errorMessage: error);
  }
}
