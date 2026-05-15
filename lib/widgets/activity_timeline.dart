import 'package:flutter/material.dart';
import '../../shared/models/models.dart' as models;
import '../../core/theme/app_theme.dart';

/// Activity timeline widget
class ActivityTimeline extends StatelessWidget {
  final int? limit;
  final Function(models.ActivityLog)? onItemTap;

  const ActivityTimeline({
    super.key,
    this.limit,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    // Mock data for now
    final activities = _getMockActivities();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _ActivityTile(
          activity: activity,
          onTap: onItemTap,
        );
      },
    );
  }

  List<models.ActivityLog> _getMockActivities() {
    final now = DateTime.now();
    return [
      models.ActivityLog(
        id: '1',
        timestamp: now.subtract(const Duration(minutes: 5)),
        eventType: models.ActivityEventType.gestureDetected,
        description: 'Lock gesture detected (92%)',
        confidence: 0.92,
      ),
      models.ActivityLog(
        id: '2',
        timestamp: now.subtract(const Duration(minutes: 10)),
        eventType: models.ActivityEventType.lockStateChanged,
        description: 'Door locked',
      ),
      models.ActivityLog(
        id: '3',
        timestamp: now.subtract(const Duration(hours: 2)),
        eventType: models.ActivityEventType.doorClose,
        description: 'Door close detected',
      ),
      models.ActivityLog(
        id: '4',
        timestamp: now.subtract(const Duration(hours: 3)),
        eventType: models.ActivityEventType.leaving,
        description: 'Leaving gesture detected',
      ),
      models.ActivityLog(
        id: '5',
        timestamp: now.subtract(const Duration(days: 1)),
        eventType: models.ActivityEventType.alertTriggered,
        description: 'Door left unlocked alert',
      ),
    ];
  }
}

/// Activity tile widget
class _ActivityTile extends StatelessWidget {
  final models.ActivityLog activity;
  final Function(models.ActivityLog)? onTap;

  const _ActivityTile({
    required this.activity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _getIconForEvent(activity.eventType),
      title: Text(activity.description ?? activity.eventType.displayName),
      subtitle: Text(_formatTimestamp(activity.timestamp)),
      trailing: activity.confidence != null
          ? _ConfidenceBadge(activity.confidence!)
          : null,
      onTap: onTap != null ? () => onTap!(activity) : null,
    );
  }

  Widget _getIconForEvent(models.ActivityEventType type) {
    IconData icon;
    Color color;

    switch (type) {
      case models.ActivityEventType.gestureDetected:
        icon = Icons.front_hand;
        color = AppTheme.primaryColor;
        break;
      case models.ActivityEventType.lockStateChanged:
        icon = Icons.lock;
        color = AppTheme.lockedColor;
        break;
      case models.ActivityEventType.alertTriggered:
        icon = Icons.notifications_active;
        color = AppTheme.unlockedColor;
        break;
      case models.ActivityEventType.alertAcknowledged:
        icon = Icons.check_circle;
        color = AppTheme.lockedColor;
        break;
      case models.ActivityEventType.monitoringStarted:
        icon = Icons.play_circle;
        color = AppTheme.primaryColor;
        break;
      case models.ActivityEventType.monitoringStopped:
        icon = Icons.stop_circle;
        color = AppTheme.textSecondary;
        break;
      case models.ActivityEventType.haConnected:
        icon = Icons.wifi;
        color = AppTheme.lockedColor;
        break;
      case models.ActivityEventType.haDisconnected:
        icon = Icons.wifi_off;
        color = AppTheme.unlockedColor;
        break;
      case models.ActivityEventType.settingsChanged:
        icon = Icons.settings;
        color = AppTheme.textSecondary;
        break;
      case models.ActivityEventType.doorClose:
        icon = Icons.door_front_door;
        color = AppTheme.primaryColor;
        break;
      case models.ActivityEventType.leaving:
        icon = Icons.directions_walk;
        color = AppTheme.unknownColor;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Confidence badge widget
class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge(this.confidence);

  @override
  Widget build(BuildContext context) {
    final percentage = (confidence * 100).toInt();
    final quality = confidence >= 0.9
        ? 'Excellent'
        : confidence >= 0.75
            ? 'Good'
            : confidence >= 0.6
                ? 'Fair'
                : 'Poor';

    final color = confidence >= 0.75
        ? AppTheme.lockedColor
        : confidence >= 0.6
            ? AppTheme.unknownColor
            : AppTheme.unlockedColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$percentage%',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
