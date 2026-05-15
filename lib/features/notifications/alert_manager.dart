import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../shared/models/models.dart' as models;
import '../../core/config/app_constants.dart';
import '../home_assistant/lock_controller.dart';
import '../gesture_detection/gesture_detector.dart';
import 'notification_service.dart';

/// Manages alert logic for door left unlocked scenarios
class AlertManager {
  final LockController _lockController;
  final NotificationService _notificationService;

  Timer? _alertTimer;
  Timer? _verificationTimer;
  DateTime? _doorCloseTime;
  bool _pendingAlert = false;

  final StreamController<models.Alert> _alertController =
      StreamController<models.Alert>.broadcast();

  final StreamController<AlertState> _stateController =
      StreamController<AlertState>.broadcast();

  /// Stream of triggered alerts
  Stream<models.Alert> get alertStream => _alertController.stream;

  /// Stream of alert state changes
  Stream<AlertState> get stateStream => _stateController.stream;

  /// Current alert state
  AlertState _currentState = const AlertState.idle();
  AlertState get currentState => _currentState;

  /// Alert timeout in seconds
  int _alertTimeout = AppConstants.defaultAlertTimeout;

  /// Whether alerts are enabled
  bool _enabled = true;

  AlertManager(this._lockController, this._notificationService) {
    _listenToLockEvents();
  }

  /// Listen to lock state changes
  void _listenToLockEvents() {
    _lockController.eventStream.listen((event) {
      switch (event.type) {
        case LockEventType.stateChanged:
          _handleLockStateChanged(event.oldState, event.newState);
          break;
        case LockEventType.unlocked:
          // Door was unlocked - might be someone leaving
          _doorCloseTime = null;
          break;
        default:
          break;
      }
    });
  }

  /// Handle gesture detection from external source
  void handleGesture(models.GestureResult gesture) {
    // No automatic alerts for current gesture types
  }

  /// Handle door close gesture
  void _handleDoorClose() {
    _doorCloseTime = DateTime.now();
    _setState(AlertState.waitingForLock(
      startedAt: DateTime.now(),
      secondsRemaining: _alertTimeout,
    ));

    // Start verification timer
    _startVerificationTimer();
  }

  /// Handle leaving gesture detected
  void _handleLeavingDetected() {
    // If door was recently closed and now leaving, check lock
    if (_doorCloseTime != null) {
      final timeSinceClose = DateTime.now().difference(_doorCloseTime!);
      if (timeSinceClose.inSeconds < 10) {
        _startVerificationTimer();
      }
    }
  }

  /// Handle lock state changed
  void _handleLockStateChanged(
    models.LockState oldState,
    models.LockState newState,
  ) {
    // Cancel any pending alerts if door was locked
    if (newState == models.LockState.locked) {
      _cancelPendingAlert();
      _setState(const AlertState.locked());
    } else if (newState == models.LockState.unlocked &&
        oldState == models.LockState.locked) {
      // Door was unlocked
      _setState(AlertState.unlocked(
        unlockedAt: DateTime.now(),
      ));
    }
  }

  /// Start verification timer
  void _startVerificationTimer() {
    _verificationTimer?.cancel();

    _verificationTimer = Timer(
      Duration(seconds: _alertTimeout),
      _verifyLockState,
    );

    // Update countdown
    _startCountdown();
  }

  /// Start countdown for state updates
  void _startCountdown() {
    int remaining = _alertTimeout;

    _alertTimer?.cancel();
    _alertTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;

      if (currentState is AlertStateWaitingForLock) {
        _setState(AlertState.waitingForLock(
          startedAt: DateTime.now(),
          secondsRemaining: remaining,
        ));
      }

      if (remaining <= 0) {
        timer.cancel();
      }
    });
  }

  /// Verify lock state after timeout
  void _verifyLockState() async {
    if (!_enabled) return;

    // Check if lock is secure
    final isUnlocked = await _lockController.checkLockAfterTimeout();

    if (isUnlocked) {
      _triggerAlert();
    } else {
      // Door was locked - all good
      _setState(const AlertState.locked());
      _logSuccessfulBehavior();
    }
  }

  /// Trigger door left unlocked alert
  void _triggerAlert() {
    if (_pendingAlert) return;
    _pendingAlert = true;

    final lockName = _lockController.selectedLock?.friendlyName ?? 'Door';
    final timeUnlocked = _lockController.getTimeSinceStateChange();

    // Create alert
    final alert = models.Alert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: models.AlertType.doorLeftUnlocked,
      title: 'Door Left Unlocked',
      message: '$lockName has been left unlocked',
      timestamp: DateTime.now(),
    );

    _setState(AlertState.alertTriggered(
      alert: alert,
      triggeredAt: DateTime.now(),
    ));

    _alertController.add(alert);

    // Show notification
    _notificationService.showDoorLeftUnlockedAlert(
      lockName: lockName,
      timeUnlocked: timeUnlocked,
    );
  }

  /// Cancel pending alert
  void _cancelPendingAlert() {
    _verificationTimer?.cancel();
    _alertTimer?.cancel();
    _pendingAlert = false;
  }

  /// User acknowledged the alert
  void acknowledgeAlert(String alertId) {
    _pendingAlert = false;
    _setState(const AlertState.idle());

    // Create acknowledgement event
    final acknowledgedAlert = models.Alert(
      id: alertId,
      type: models.AlertType.doorLeftUnlocked,
      title: 'Alert Acknowledged',
      message: 'User acknowledged the door was left unlocked',
      timestamp: DateTime.now(),
      acknowledged: true,
    );

    _alertController.add(acknowledgedAlert);
  }

  /// User marked door as secured
  void markAsSecured(String alertId) {
    _pendingAlert = false;
    _setState(const AlertState.locked());

    final securedAlert = models.Alert(
      id: alertId,
      type: models.AlertType.doorLeftUnlocked,
      title: 'Marked as Secured',
      message: 'User confirmed door is now secured',
      timestamp: DateTime.now(),
      acknowledged: true,
    );

    _alertController.add(securedAlert);
  }

  /// Snooze alert for a period
  void snoozeAlert(String alertId, Duration duration) {
    _pendingAlert = false;
    _setState(const AlertState.snoozed());

    // Schedule reminder
    _notificationService.scheduleReminder(
      title: 'Door Lock Reminder',
      body: 'Please check if your door is locked',
      scheduledTime: DateTime.now().add(duration),
    );

    // Reset state after snooze
    Timer(duration, () {
      if (_lockController.currentState == models.LockState.unlocked) {
        _triggerAlert();
      }
    });
  }

  /// Manually trigger an alert (for testing)
  void triggerTestAlert() {
    final alert = models.Alert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: models.AlertType.doorLeftUnlocked,
      title: 'Test Alert',
      message: 'This is a test alert',
      timestamp: DateTime.now(),
    );

    _alertController.add(alert);
    _notificationService.showDoorLeftUnlockedAlert(
      lockName: 'Test Door',
    );
  }

  /// Log successful behavior (door was locked)
  void _logSuccessfulBehavior() {
    if (kDebugMode) {
      print('Door was locked successfully - no alert needed');
    }
    // Analytics could be logged here
  }

  /// Set alert timeout
  void setAlertTimeout(int seconds) {
    _alertTimeout = seconds.clamp(1, 60);
  }

  /// Enable or disable alerts
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _cancelPendingAlert();
    }
  }

  /// Update current state
  void _setState(AlertState state) {
    _currentState = state;
    _stateController.add(state);
  }

  /// Reset the alert manager
  void reset() {
    _cancelPendingAlert();
    _doorCloseTime = null;
    _pendingAlert = false;
    _setState(const AlertState.idle());
  }

  /// Dispose resources
  void dispose() async {
    _cancelPendingAlert();
    await _alertController.close();
    await _stateController.close();
  }
}

/// Alert state sealed class
sealed class AlertState {
  const AlertState();

  const factory AlertState.idle() = AlertStateIdle;
  const factory AlertState.unlocked({required DateTime unlockedAt}) = AlertStateUnlocked;
  const factory AlertState.waitingForLock({
    required DateTime startedAt,
    required int secondsRemaining,
  }) = AlertStateWaitingForLock;
  const factory AlertState.locked() = AlertStateLocked;
  const factory AlertState.alertTriggered({
    required models.Alert alert,
    required DateTime triggeredAt,
  }) = AlertStateAlertTriggered;
  const factory AlertState.snoozed() = AlertStateSnoozed;
}

class AlertStateIdle extends AlertState {
  const AlertStateIdle();
}

class AlertStateUnlocked extends AlertState {
  final DateTime unlockedAt;
  const AlertStateUnlocked({required this.unlockedAt});
}

class AlertStateWaitingForLock extends AlertState {
  final DateTime startedAt;
  final int secondsRemaining;
  const AlertStateWaitingForLock({
    required this.startedAt,
    required this.secondsRemaining,
  });
}

class AlertStateLocked extends AlertState {
  const AlertStateLocked();
}

class AlertStateAlertTriggered extends AlertState {
  final models.Alert alert;
  final DateTime triggeredAt;
  const AlertStateAlertTriggered({
    required this.alert,
    required this.triggeredAt,
  });
}

class AlertStateSnoozed extends AlertState {
  const AlertStateSnoozed();
}
