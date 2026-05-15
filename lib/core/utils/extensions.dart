import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Utility extensions and helper functions
class AppUtils {
  /// Format timestamp to readable string
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Format full date and time
  static String formatFullDateTime(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// Calculate distance between two points
  static double distance(double x1, double y1, double x2, double y2) {
    return ((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
  }

  /// Calculate angle between three points (in degrees)
  static double calculateAngle(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    final angle = math.atan2(y3 - y2, x3 - x2) - math.atan2(y1 - y2, x1 - x2);
    double degrees = angle * 180 / math.pi;
    if (degrees < 0) degrees += 360;
    return degrees;
  }

  /// Map value from one range to another
  static double mapRange(
    double value,
    double inMin,
    double inMax,
    double outMin,
    double outMax,
  ) {
    return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
  }

  /// Clamp value between min and max
  static double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Validate URL format
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  /// Validate Home Assistant URL
  static bool isValidHaUrl(String url) {
    if (!isValidUrl(url)) return false;
    final uri = Uri.parse(url);
    // Remove port if present
    final hostWithoutPort = uri.host;
    // Basic validation - should not be empty
    return hostWithoutPort.isNotEmpty;
  }

  /// Get a readable error message from common exceptions
  static String getErrorMessage(dynamic error) {
    if (error is Exception) {
      final message = error.toString();
      if (message.contains('Network')) {
        return 'Network error. Please check your connection.';
      } else if (message.contains('Timeout')) {
        return 'Request timed out. Please try again.';
      } else if (message.contains('Permission')) {
        return 'Permission denied. Please check app permissions.';
      } else if (message.contains('Authentication')) {
        return 'Authentication failed. Please check your credentials.';
      }
      return message;
    }
    return error.toString();
  }

  /// Show a snackbar message
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a loading dialog
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Hide current dialog
  static void hideDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
}
