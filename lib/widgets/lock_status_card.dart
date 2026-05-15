import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart' as models;

/// Lock status card widget
class LockStatusCard extends StatelessWidget {
  final models.LockState state;
  final DateTime? lastChange;
  final bool isMonitoring;
  final VoidCallback onRefresh;
  final VoidCallback onToggleMonitoring;

  const LockStatusCard({
    super.key,
    required this.state,
    this.lastChange,
    this.isMonitoring = false,
    required this.onRefresh,
    required this.onToggleMonitoring,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.getStatusColor(state);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      models.LockStateExtension(state).iconName == 'lock'
                          ? Icons.lock
                          : Icons.lock_open,
                      color: statusColor,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Front Door',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          models.LockStateExtension(state).displayName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Monitoring toggle
                    _StatusChip(
                      label: isMonitoring ? 'Monitoring' : 'Idle',
                      isActive: isMonitoring,
                      onTap: onToggleMonitoring,
                    ),
                    const SizedBox(width: 8),
                    // Refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: onRefresh,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Status details
            Row(
              children: [
                _DetailItem(
                  icon: Icons.access_time,
                  label: 'Last Changed',
                  value: _formatTime(lastChange),
                ),
                const SizedBox(width: 24),
                _DetailItem(
                  icon: Icons.wifi,
                  label: 'Connection',
                  value: 'Connected',
                  valueColor: AppTheme.lockedColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Status progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state == models.LockState.locked ? 1.0 : 0.0,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Unknown';

    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Detail item widget
class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: valueColor ?? AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

/// Status chip widget
class _StatusChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.lockedColor.withValues(alpha: 0.2)
              : Colors.grey[200],
          border: Border.all(
            color: isActive ? AppTheme.lockedColor : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: AppTheme.lockedColor,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.lockedColor : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
