import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Quick actions widget for common tasks
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.camera_alt,
                label: 'Open Camera',
                color: AppTheme.primaryColor,
                onTap: () {
                  Navigator.pushNamed(context, '/camera');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.lock,
                label: 'Lock Door',
                color: AppTheme.lockedColor,
                onTap: () {
                  _showLockDialog(context, true);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.lock_open,
                label: 'Unlock',
                color: AppTheme.unlockedColor,
                onTap: () {
                  _showLockDialog(context, false);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLockDialog(BuildContext context, bool lock) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lock ? 'Lock Door' : 'Unlock Door'),
        content: Text(
          lock
              ? 'Are you sure you want to lock the door?'
              : 'Are you sure you want to unlock the door?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(lock ? 'Door locked' : 'Door unlocked'),
                  backgroundColor: lock
                      ? AppTheme.lockedColor
                      : AppTheme.unlockedColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: lock
                  ? AppTheme.lockedColor
                  : AppTheme.unlockedColor,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

/// Action button widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
