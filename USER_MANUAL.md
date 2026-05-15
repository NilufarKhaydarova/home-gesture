# User Manual

## Overview

This app is a gesture-controlled smart-home demo built with Flutter. It combines a dashboard, a camera-based gesture screen, an activity view, and a settings area for Home Assistant and monitoring preferences.

The current build mixes working features with demo-only behavior. This manual documents both so you know what to expect before using it.

## What This Build Can Do

- Show a Home dashboard with gesture shortcuts and daily stats.
- Open a live camera preview.
- Detect three gestures in supported camera-stream builds.
- Trigger in-app automation states for lights and music.
- Save app settings locally on the device.

## Current Limitations

- On macOS, the camera preview works, but real-time frame streaming is disabled in this build. You can open the camera, but live gesture detection will not run.
- The Activity screen currently shows mock sample events rather than a real event history.
- Home Assistant connection testing currently returns a demo success message after a short delay.
- Lock entity selection currently uses a fixed sample list.
- The "Calibrate Handle Position" setting is visible, but no calibration flow is implemented yet.
- On web, the Flutter shell redirects to `smart-home.html`, which is a separate browser experience from the native Flutter camera flow.

## Supported Gestures And Actions

The camera automation screen recognizes these gestures:

| Gesture | How it is detected | Result |
| --- | --- | --- |
| Wave | Wrist raised above the shoulder with side-to-side motion | Toggles music on or off |
| Eyes Closed | Eyes remain closed for about 10 seconds | Turns off the main light |
| Tummy Rub | A hand is held over the abdomen area | Toggles the kitchen light |

Notes:

- Gesture detections are debounced for about 2 seconds to avoid repeated triggers.
- Eyes-closed detection requires you to keep your eyes closed long enough to cross the timer threshold.
- Detection confidence must pass an internal minimum threshold before the app triggers an action.

## Starting The App

### macOS

From the `home_gesture` folder:

```bash
flutter pub get
flutter run -d macos
```

Use macOS when you want to review the interface and camera preview. Live gesture detection is not available on macOS in this build.

### Chrome

From the `home_gesture` folder:

```bash
flutter pub get
flutter run -d chrome
```

When the web app starts, it redirects to `smart-home.html`.

### Mobile Device

From the `home_gesture` folder:

```bash
flutter pub get
flutter run
```

Use a physical Android or iOS device if you want the best chance of testing live camera-based gesture detection.

## First-Time Setup

1. Launch the app.
2. Open the `Settings` tab.
3. Review notification, monitoring, and sensitivity defaults.
4. If you plan to connect Home Assistant, enter the server URL and access token.
5. Grant camera access when the system asks for permission.

Settings are stored locally and remain available the next time you open the app.

## Main Navigation

The app uses three bottom navigation tabs:

- `Home`: dashboard, quick actions, and summary stats.
- `Activity`: timeline of recent activity entries.
- `Settings`: Home Assistant, notification, and detection preferences.

The `Home` tab also shows a floating `Camera` button that opens the gesture camera screen.

## Home Screen

The Home screen contains three main areas.

### Current Gesture Card

This card shows:

- the most recently recognized gesture
- when it was last detected
- a color-coded state banner

If nothing has been detected yet, the card shows `No Detection`.

### Quick Actions

The quick-action buttons simulate supported gestures directly from the dashboard. Use them to preview the app response without opening the camera.

Each tap updates the current gesture card and increments the daily detections count.

### Daily Stats

The stats section summarizes the number of detections and the latest gesture state for the current session.

## Camera Screen

Open the camera screen by tapping the floating `Camera` button on the Home tab.

The camera screen includes:

- a live camera preview
- a status message showing camera or detection state
- a last-gesture banner when an action fires
- an automation panel showing the current in-app device state
- usage instructions for supported gestures
- controls for detection and overlay visibility

### What Happens On Detection

When a valid gesture is recognized:

1. The detection status updates.
2. The relevant in-app device state changes.
3. A snackbar appears with the detected action and confidence value.

### In-App Device States

The automation panel tracks these demo states:

- `Main light`
- `Music`
- `Kitchen light`

These are in-app demo states only. They do not currently control real devices by themselves.

## Activity Screen

The Activity tab shows a timeline with event icons, labels, timestamps, and confidence badges when available.

Important: the current timeline is mock data intended to demonstrate the UI. It is not yet wired to the real detection or settings history.

## Settings Screen

The Settings tab is divided into five sections.

### Home Assistant

Available options:

- `Server URL`
- `Access Token`
- `Test Connection`
- `Select Lock Entity`

How to use it:

1. Enter your Home Assistant URL.
2. Enter a long-lived access token.
3. Run `Test Connection`.
4. If a server URL is set, choose a lock entity from the available sample list.

Current behavior:

- Connection testing is a demo flow and currently shows a successful result without a real server check.
- The lock entity picker currently offers a fixed list of sample entities.

### Notifications

Available options:

- `Enable Notifications`
- `Alert Timeout`

Use this section to control whether alerts are enabled and how long the app waits before raising a timeout-based alert.

### Gesture Detection

Available options:

- `Enable Monitoring`
- `Sensitivity`
- `Calibrate Handle Position`

Use this section to enable monitoring and tune how sensitive detection should be. Higher sensitivity means the app will react more readily, but it may also increase false positives.

Current behavior:

- `Calibrate Handle Position` is not implemented yet.

### Data

The app includes a data section in the settings screen for future storage and management tasks.

### About

The about section provides basic app information.

## Tips For Better Detection

- Use a well-lit room.
- Keep your face and upper body clearly visible in frame.
- For a wave, raise your hand above shoulder level and move it side to side.
- For tummy rub, keep one hand over the abdomen area long enough for the detector to see it clearly.
- For eyes closed, stay still and keep both eyes closed for roughly 10 seconds.
- Avoid standing too far from the camera.

## Troubleshooting

### Camera Does Not Start

- Confirm that camera permission is allowed in macOS, iOS, Android, or browser settings.
- Close other apps that may already be using the camera.
- Reopen the camera screen and try again.

### No Gestures Are Detected

- Confirm you are testing on a build that supports frame streaming.
- On macOS, gesture detection is not available in this build even though preview works.
- Improve lighting and keep your body centered in the frame.
- Make the gesture more clearly and hold it long enough to be recognized.

### Settings Do Not Seem To Apply

- Most settings are stored locally and should persist after changes.
- If Home Assistant actions do not affect real devices, that is expected in the current build because the integration flow is still partial.

### Activity History Looks Unrealistic

- That is expected. The current Activity screen uses sample data for demonstration.

## Data And Privacy Notes

- The app requires camera access for preview and gesture recognition.
- Settings such as Home Assistant URL, token, selected lock entity, notification preferences, sensitivity, and monitoring state are stored locally on the device.

## Summary

Use this build primarily as a working prototype for gesture-driven home automation flows. The camera UI, local settings, and in-app automation states are present today. Some integration pieces, especially Home Assistant verification, real activity history, calibration, and macOS live detection, are still incomplete.