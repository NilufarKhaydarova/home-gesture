import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../features/automation/simple_automation.dart';
import '../camera/camera_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/activity_timeline.dart' show ActivityTimeline;

/// Main home screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    _DashboardScreen(),
    _ActivityScreen(),
    _SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraScreen()),
                );
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
              backgroundColor: AppTheme.primaryColor,
            )
          : null,
    );
  }
}

/// Main dashboard widget
class _DashboardScreen extends StatefulWidget {
  const _DashboardScreen();

  @override
  State<_DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<_DashboardScreen> {
  GestureType? _currentGesture;
  int _todayDetections = 0;
  DateTime? _lastDetectionTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gesture Detection'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Gesture Card
            _CurrentGestureCard(
              gesture: _currentGesture,
              lastDetection: _lastDetectionTime,
            ),

            const SizedBox(height: 24),

            // Quick Actions Section
            _GestureButtonsSection(
              onTrigger: _handleTrigger,
            ),

            const SizedBox(height: 24),

            // Today's Stats
            _StatsCard(
              detections: _todayDetections,
              currentGesture: _currentGesture,
            ),
          ],
        ),
      ),
    );
  }

  void _handleTrigger(GestureType gesture) {
    final action = SimpleAutomation.getAction(gesture);
    if (action != null) {
      setState(() {
        _currentGesture = gesture;
        _todayDetections++;
        _lastDetectionTime = DateTime.now();
      });
    }
  }
}

/// Current gesture display card
class _CurrentGestureCard extends StatelessWidget {
  final GestureType? gesture;
  final DateTime? lastDetection;

  const _CurrentGestureCard({
    required this.gesture,
    this.lastDetection,
  });

  @override
  Widget build(BuildContext context) {
    final color = gesture != null
        ? AppTheme.getGestureColor(gesture!)
        : AppTheme.unknownColor;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Column(
          children: [
            Icon(
              gesture?.icon ?? Icons.help_outline,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              gesture?.displayName ?? 'No Detection',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              lastDetection != null
                  ? 'Detected ${_formatTime(lastDetection!)}'
                  : 'Waiting for gesture...',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
}

/// Gesture buttons section
class _GestureButtonsSection extends StatelessWidget {
  final Function(GestureType) onTrigger;

  const _GestureButtonsSection({required this.onTrigger});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: GestureType.values
              .where((g) => g != GestureType.unknown)
              .map((gesture) => _GestureButton(
                    gesture: gesture,
                    onTap: () => onTrigger(gesture),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

/// Individual gesture button
class _GestureButton extends StatelessWidget {
  final GestureType gesture;
  final VoidCallback onTap;

  const _GestureButton({
    required this.gesture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getGestureColor(gesture);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                gesture.icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                gesture.displayName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stats card
class _StatsCard extends StatelessWidget {
  final int detections;
  final GestureType? currentGesture;

  const _StatsCard({
    required this.detections,
    required this.currentGesture,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's Stats",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.camera_alt,
                    label: 'Detections',
                    value: detections.toString(),
                    color: AppTheme.primaryColor,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: currentGesture?.icon ?? Icons.help_outline,
                    label: 'Last Gesture',
                    value: currentGesture?.displayName ?? 'None',
                    color: currentGesture != null
                        ? AppTheme.getGestureColor(currentGesture!)
                        : AppTheme.unknownColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual stat item
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Activity timeline screen
class _ActivityScreen extends StatelessWidget {
  const _ActivityScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        centerTitle: true,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ActivityTimeline(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings screen
class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}
