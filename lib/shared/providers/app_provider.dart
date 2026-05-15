import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_constants.dart';
import '../../shared/models/models.dart';
import '../../core/analytics/logger.dart';

/// Main app state provider
class AppProvider extends ChangeNotifier {
  UserSettings _settings = const UserSettings();
  bool _isInitialized = false;
  bool _isLoading = false;

  final ResearchLogger _logger = ResearchLogger();

  UserSettings get settings => _settings;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  /// Initialize provider and load settings
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _logger.initialize();
      await _loadSettings();
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing app: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load settings from persistent storage
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _settings = UserSettings(
      haUrl: prefs.getString(AppConstants.keyHaUrl),
      haToken: prefs.getString(AppConstants.keyHaToken),
      selectedLockEntity: prefs.getString(AppConstants.keySelectedLockEntity),
      notificationsEnabled:
          prefs.getBool(AppConstants.keyNotificationsEnabled) ??
              AppConstants.defaultNotificationsEnabled,
      sensitivity:
          prefs.getInt(AppConstants.keySensitivity) ?? AppConstants.defaultSensitivity,
      monitoringEnabled:
          prefs.getBool(AppConstants.keyMonitoringEnabled) ??
              AppConstants.defaultMonitoringEnabled,
      alertTimeout:
          prefs.getInt(AppConstants.keyAlertTimeout) ?? AppConstants.defaultAlertTimeout,
    );
  }

  /// Save settings to persistent storage
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (_settings.haUrl != null) {
      await prefs.setString(AppConstants.keyHaUrl, _settings.haUrl!);
    }
    if (_settings.haToken != null) {
      await prefs.setString(AppConstants.keyHaToken, _settings.haToken!);
    }
    if (_settings.selectedLockEntity != null) {
      await prefs.setString(
        AppConstants.keySelectedLockEntity,
        _settings.selectedLockEntity!,
      );
    }
    await prefs.setBool(
      AppConstants.keyNotificationsEnabled,
      _settings.notificationsEnabled,
    );
    await prefs.setInt(AppConstants.keySensitivity, _settings.sensitivity);
    await prefs.setBool(
      AppConstants.keyMonitoringEnabled,
      _settings.monitoringEnabled,
    );
    await prefs.setInt(AppConstants.keyAlertTimeout, _settings.alertTimeout);
  }

  /// Update Home Assistant URL
  Future<void> setHaUrl(String? url) async {
    final oldUrl = _settings.haUrl;
    _settings = _settings.copyWith(haUrl: url);
    await _saveSettings();
    notifyListeners();

    await _logger.logSettingsChange(
      setting: 'ha_url',
      oldValue: oldUrl,
      newValue: url,
    );
  }

  /// Update Home Assistant token
  Future<void> setHaToken(String? token) async {
    final oldToken = _settings.haToken;
    _settings = _settings.copyWith(haToken: token);
    await _saveSettings();
    notifyListeners();

    await _logger.logSettingsChange(
      setting: 'ha_token',
      oldValue: oldToken ?? '',
      newValue: token ?? '',
    );
  }

  /// Update selected lock entity
  Future<void> setSelectedLockEntity(String? entityId) async {
    final oldEntity = _settings.selectedLockEntity;
    _settings = _settings.copyWith(selectedLockEntity: entityId);
    await _saveSettings();
    notifyListeners();

    await _logger.logSettingsChange(
      setting: 'selected_lock_entity',
      oldValue: oldEntity,
      newValue: entityId,
    );
  }

  /// Update notifications enabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    final oldValue = _settings.notificationsEnabled;
    _settings = _settings.copyWith(notificationsEnabled: enabled);
    await _saveSettings();
    notifyListeners();

    await _logger.logSettingsChange(
      setting: 'notifications_enabled',
      oldValue: oldValue,
      newValue: enabled,
    );
  }

  /// Update sensitivity
  Future<void> setSensitivity(int sensitivity) async {
    final clamped = sensitivity.clamp(0, 100);
    final oldValue = _settings.sensitivity;
    _settings = _settings.copyWith(sensitivity: clamped);
    await _saveSettings();
    notifyListeners();

    await _logger.logSettingsChange(
      setting: 'sensitivity',
      oldValue: oldValue,
      newValue: clamped,
    );
  }

  /// Update monitoring enabled
  Future<void> setMonitoringEnabled(bool enabled) async {
    final oldValue = _settings.monitoringEnabled;
    _settings = _settings.copyWith(monitoringEnabled: enabled);
    await _saveSettings();
    notifyListeners();

    await _logger.logSettingsChange(
      setting: 'monitoring_enabled',
      oldValue: oldValue,
      newValue: enabled,
    );
  }

  /// Update alert timeout
  Future<void> setAlertTimeout(int seconds) async {
    final clamped = seconds.clamp(1, 60);
    final oldValue = _settings.alertTimeout;
    _settings = _settings.copyWith(alertTimeout: clamped);
    await _saveSettings();
    notifyListeners();

    await _logger.logSettingsChange(
      setting: 'alert_timeout',
      oldValue: oldValue,
      newValue: clamped,
    );
  }

  /// Get logger instance
  ResearchLogger get logger => _logger;

  @override
  void dispose() {
    _logger.dispose();
    super.dispose();
  }
}
