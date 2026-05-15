/// App-wide constants and configuration values
class AppConstants {
  // App Info
  static const String appName = 'Baby Monitor';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String keyHaUrl = 'ha_url';
  static const String keyHaToken = 'ha_token';
  static const String keySelectedLockEntity = 'selected_lock_entity';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keySensitivity = 'gesture_sensitivity';
  static const String keyMonitoringEnabled = 'monitoring_enabled';
  static const String keyAlertTimeout = 'alert_timeout_seconds';
  static const String keyDoorHandleCalibration = 'door_handle_calibration';

  // Default Values
  static const int defaultSensitivity = 50; // 0-100 scale
  static const int defaultAlertTimeout = 5; // seconds
  static const bool defaultNotificationsEnabled = true;
  static const bool defaultMonitoringEnabled = false;

  // Gesture Detection Constants
  static const double minPoseDetectionConfidence = 0.5;
  static const double minGestureConfidence = 0.7;
  static const int gestureHistoryLength = 10;

  // Door handle region (normalized coordinates 0-1)
  static const double defaultHandleRegionX = 0.8;
  static const double defaultHandleRegionY = 0.4;
  static const double handleRegionSize = 0.15;

  // Lock gesture thresholds
  static const double wristRotationThreshold = 30.0; // degrees
  static const double handReachThreshold = 0.6; // normalized
  static const double bodyOrientationThreshold = 45.0; // degrees

  // Camera Constants
  static const int cameraResolutionWidth = 1280;
  static const int cameraResolutionHeight = 720;
  static const int cameraFps = 30;

  // Home Assistant Constants
  static const String haDefaultPort = '8123';
  static const String haWebSocketPath = '/api/websocket';
  static const int haConnectionTimeout = 10; // seconds
  static const int haReconnectDelay = 5; // seconds

  // Notification Constants
  static const String notificationChannelId = 'door_monitor_channel';
  static const String notificationChannelName = 'Door Lock Monitor';
  static const String notificationChannelDescription = 'Alerts for door lock monitoring';
  static const int notificationId = 1001;

  // Analytics/Logging Constants
  static const String logFileName = 'gesture_events.log';
  static const int maxLogFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxLogFiles = 5;

  // Asset paths
  static const String assetIconsPath = 'assets/icons/';
  static const String assetImagesPath = 'assets/images/';
}
