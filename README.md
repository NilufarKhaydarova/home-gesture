# Hand Gesture Detection Demo

A clean, professional Flutter web demo for hand gesture detection.

## Features

- **Working Camera Preview** on Chrome and other browsers
- **Real-time Gesture Detection** (simulated on web, ready for MediaPipe integration)
- **Clean, Modern UI** with gradient backgrounds and glassmorphism effects
- **Gesture Status Display** showing detected gestures with confidence levels
- **Interactive Controls** to start/stop detection and toggle overlays

## Supported Gestures

1. **Open Hand** - All fingers extended
2. **Closed Fist** - All fingers curled
3. **Pointing** - Index finger extended
4. **Thumbs Up** - Thumb extended upward
5. **Peace Sign** - Index and middle fingers extended

## Running the Demo

### On Web (Chrome)

```bash
flutter pub get
flutter run -d chrome
```

### On Mobile

```bash
flutter pub get
flutter run
```

## Architecture

### Core Components

- **`lib/main.dart`** - App entry point
- **`lib/screens/camera_screen.dart`** - Main camera and gesture detection UI
- **`lib/services/camera_service.dart`** - Camera initialization and control
- **`lib/services/gesture_detector.dart`** - Gesture detection logic
- **`lib/models/gesture_model.dart`** - Gesture type and result models

### Platform Support

- **Web**: Working camera preview with simulated gesture detection
- **Android/iOS**: Ready for ML Kit integration
- **macOS**: Camera preview with simulated gestures

## Demo Mode

On web platforms, gesture detection runs in demo mode with simulated gestures for demonstration purposes. This is because MediaPipe/ML Kit don't work directly in Flutter Web yet.

To enable real gesture detection on mobile platforms, integrate with:
- **MediaPipe Hands** via platform channels
- **ML Kit** for native gesture detection
- **TensorFlow Lite** with hand detection models

## UI Features

- Dark gradient background (slate color scheme)
- Rounded camera preview with glassmorphism effects
- Real-time gesture status display
- Confidence indicator with progress bar
- Gesture chips showing all supported gestures
- Start/Stop detection controls
- Show/Hide overlay toggle

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.12.0+1
  cupertino_icons: ^1.0.8
```

## Future Enhancements

1. Integrate MediaPipe Hands for real web gesture detection
2. Add more gesture types (pinch, swipe, etc.)
3. Implement gesture-based actions
4. Add gesture history/timeline
5. Support multiple hands detection
6. Add gesture recording and playback

## Troubleshooting

### Camera Not Working

- Ensure you've granted camera permissions in your browser
- Check that no other app is using the camera
- Try refreshing the page and granting permissions again

### Web Build Issues

- Use Chrome browser for best compatibility
- Ensure you're using Flutter 3.10.8 or higher
- Clear browser cache if needed

## License

MIT License - Feel free to use this as a starting point for your own gesture detection projects.