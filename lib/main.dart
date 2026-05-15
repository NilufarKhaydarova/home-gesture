import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/camera_screen.dart';
import 'screens/web_smart_home_screen.dart';

void main() {
  runApp(const GestureDetectionApp());
}

class GestureDetectionApp extends StatelessWidget {
  const GestureDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gesture Detection Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: kIsWeb ? const WebSmartHomeScreen() : const CameraScreen(),
    );
  }
}