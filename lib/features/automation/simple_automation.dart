import 'package:flutter/material.dart';
import '../../shared/models/models.dart';
import '../../core/theme/app_theme.dart';

/// Automation action model for gesture responses
class AutomationAction {
  final String message;
  final List<String> actions;
  final IconData icon;
  final Color color;

  const AutomationAction({
    required this.message,
    required this.actions,
    required this.icon,
    required this.color,
  });
}

/// Home device state managed by automation
class HomeDeviceState {
  bool mainLightOn;
  bool musicPlaying;
  bool kitchenLightOn;

  HomeDeviceState({
    this.mainLightOn = true,
    this.musicPlaying = false,
    this.kitchenLightOn = false,
  });
}

/// Simple automation service mapping gestures to home device actions
class SimpleAutomation {
  static final HomeDeviceState devices = HomeDeviceState();

  /// Map gestures to automation actions
  static Map<GestureType, AutomationAction> get actions => {
        GestureType.wave: AutomationAction(
          message: devices.musicPlaying
              ? 'Wave detected — Stopping music'
              : 'Wave detected — Playing music',
          actions: ['Toggle music'],
          icon: Icons.music_note,
          color: AppTheme.wavingColor,
        ),
        GestureType.eyesClosed: AutomationAction(
          message: 'Eyes closed — Turning off main light',
          actions: ['Turn off main light'],
          icon: Icons.lightbulb_outline,
          color: AppTheme.cryingColor,
        ),
        GestureType.tummyRub: AutomationAction(
          message: devices.kitchenLightOn
              ? 'Tummy rub — Turning off kitchen'
              : 'Tummy rub — Turning on kitchen',
          actions: ['Toggle kitchen light'],
          icon: Icons.kitchen,
          color: AppTheme.thumbsUpColor,
        ),
        GestureType.unknown: AutomationAction(
          message: 'Unknown gesture',
          actions: ['No action'],
          icon: Icons.help_outline,
          color: AppTheme.unknownColor,
        ),
      };

  /// Apply gesture to device state and return the action
  static AutomationAction? applyGesture(GestureType gesture) {
    switch (gesture) {
      case GestureType.wave:
        devices.musicPlaying = !devices.musicPlaying;
        break;
      case GestureType.eyesClosed:
        devices.mainLightOn = false;
        break;
      case GestureType.tummyRub:
        devices.kitchenLightOn = !devices.kitchenLightOn;
        break;
      case GestureType.unknown:
        return null;
    }
    return actions[gesture];
  }

  /// Get automation action for a gesture (read-only, no state change)
  static AutomationAction? getAction(GestureType gesture) {
    return actions[gesture];
  }

  /// Reset all devices to defaults
  static void reset() {
    devices.mainLightOn = true;
    devices.musicPlaying = false;
    devices.kitchenLightOn = false;
  }
}
