import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../shared/models/models.dart' as models;
import '../../core/config/app_constants.dart';

/// Local notification service
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _enabled = true;

  /// Whether notifications are initialized
  bool get isInitialized => _initialized;

  /// Whether notifications are enabled
  bool get isEnabled => _enabled;

  /// Initialize notification service
  Future<bool> initialize() async {
    if (_initialized) return true;

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialization settings
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize plugin
    final result = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = result ?? false;
    return _initialized;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final result = await androidPlugin.requestNotificationsPermission();
      return result ?? false;
    }

    return true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
    // Handle notification tap (navigation, etc.)
  }

  /// Show door left unlocked alert
  Future<void> showDoorLeftUnlockedAlert({
    String? lockName,
    Duration? timeUnlocked,
  }) async {
    if (!_enabled || !_initialized) return;

    final lockNameText = lockName ?? 'Door';
    final timeText = timeUnlocked != null
        ? ' for ${timeUnlocked.inMinutes} minutes'
        : '';

    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      actions: [
        AndroidNotificationAction(
          'mark_secured',
          'Mark as Secured',
        ),
        AndroidNotificationAction(
          'snooze',
          'Snooze',
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'door_alert',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      AppConstants.notificationId,
      '🚪 Door Left Unlocked!',
      '$lockNameText has been left unlocked$timeText. Please secure your home.',
      details,
      payload: 'door_left_unlocked',
    );
  }

  /// Show lock state changed notification
  Future<void> showLockStateChanged({
    required models.LockState newState,
    String? lockName,
  }) async {
    if (!_enabled || !_initialized) return;

    final lockNameText = lockName ?? 'Door';
    final (title, message) = _getLockStateMessage(newState, lockNameText);

    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      message,
      details,
      payload: 'lock_state_changed',
    );
  }

  /// Show gesture detected notification (debug/testing)
  Future<void> showGestureDetected({
    required models.GestureType gesture,
    double confidence = 0,
  }) async {
    if (!_enabled || !_initialized) return;

    final message = confidence > 0
        ? '${gesture.displayName} detected (${(confidence * 100).toInt()}% confidence)'
        : '${gesture.displayName} detected';

    const androidDetails = AndroidNotificationDetails(
      '${AppConstants.notificationChannelId}_debug',
      'Gesture Debug',
      channelDescription: 'Debug notifications for gesture detection',
      importance: Importance.low,
      priority: Priority.low,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Gesture Detected',
      message,
      details,
    );
  }

  /// Show connection status notification
  Future<void> showConnectionStatus({
    required bool connected,
    String? url,
  }) async {
    if (!_enabled || !_initialized) return;

    final title = connected ? 'Connected to Home Assistant' : 'Disconnected';
    final message = connected
        ? 'Successfully connected to ${url ?? "Home Assistant"}'
        : 'Lost connection to Home Assistant';

    const androidDetails = AndroidNotificationDetails(
      '${AppConstants.notificationChannelId}_status',
      'Connection Status',
      channelDescription: 'Connection status notifications',
      importance: Importance.low,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      message,
      details,
    );
  }

  /// Schedule a reminder notification
  Future<void> scheduleReminder({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_enabled || !_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      scheduledTime.millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancel specific notification
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Get active notifications (returns empty list for iOS)
  Future<List<ActiveNotification>> getActiveNotifications() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final activeNotifications = await androidPlugin.getActiveNotifications();
      return activeNotifications.map((not) => ActiveNotification(
        id: not.id ?? 0,
        title: not.title,
        body: not.body,
      )).toList();
    }

    return [];
  }

  /// Create notification channel (Android)
  Future<void> createChannel({
    required String id,
    required String name,
    required String description,
    Importance importance = Importance.defaultImportance,
  }) async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final channel = AndroidNotificationChannel(
        id,
        name,
        description: description,
        importance: importance,
      );
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  /// Enable or disable notifications
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Get notification message for lock state
  (String, String) _getLockStateMessage(models.LockState state, String lockName) {
    switch (state) {
      case models.LockState.locked:
        return ('🔒 Door Locked', '$lockName has been locked');
      case models.LockState.unlocked:
        return ('🔓 Door Unlocked', '$lockName has been unlocked');
      case models.LockState.jammed:
        return ('⚠️ Door Jammed', '$lockName appears to be jammed');
      case models.LockState.unknown:
        return ('❓ Status Unknown', 'Could not determine $lockName status');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _notifications.cancelAll();
  }
}

/// Active notification model
class ActiveNotification {
  final int id;
  final String? title;
  final String? body;

  const ActiveNotification({
    required this.id,
    this.title,
    this.body,
  });
}
