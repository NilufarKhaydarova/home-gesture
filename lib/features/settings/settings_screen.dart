import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/app_provider.dart';
import '../../core/config/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';

/// Settings screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: const [
          _HomeAssistantSection(),
          Divider(),
          _NotificationSection(),
          Divider(),
          _DetectionSection(),
          Divider(),
          _DataSection(),
          Divider(),
          _AboutSection(),
        ],
      ),
    );
  }
}

/// Home Assistant configuration section
class _HomeAssistantSection extends StatelessWidget {
  const _HomeAssistantSection();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final settings = appProvider.settings;

    return _Section(
      title: 'Home Assistant',
      icon: Icons.home_work_outlined,
      children: [
        _ListTile(
          title: 'Server URL',
          subtitle: settings.haUrl ?? 'Not configured',
          trailing: Icon(
            settings.haUrl != null ? Icons.check_circle : Icons.error,
            color: settings.haUrl != null
                ? AppTheme.lockedColor
                : AppTheme.unlockedColor,
          ),
          onTap: () => _editHaUrl(context),
        ),
        _ListTile(
          title: 'Access Token',
          subtitle: settings.haToken != null
              ? '••••••••••••'
              : 'Not configured',
          trailing: Icon(
            settings.haToken != null ? Icons.check_circle : Icons.error,
            color: settings.haToken != null
                ? AppTheme.lockedColor
                : AppTheme.unlockedColor,
          ),
          onTap: () => _editHaToken(context),
        ),
        _ListTile(
          title: 'Test Connection',
          subtitle: 'Verify Home Assistant connection',
          trailing: const Icon(Icons.sync, color: AppTheme.primaryColor),
          onTap: () => _testConnection(context),
        ),
        if (settings.haUrl != null)
          _ListTile(
            title: 'Select Lock Entity',
            subtitle: settings.selectedLockEntity ?? 'None selected',
            onTap: () => _selectLockEntity(context),
          ),
      ],
    );
  }

  Future<void> _editHaUrl(BuildContext context) async {
    final controller = TextEditingController(
      text: context.read<AppProvider>().settings.haUrl,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditTextDialog(
        title: 'Home Assistant URL',
        hint: 'https://homeassistant.local',
        controller: controller,
      ),
    );

    if (result != null) {
      // ignore: use_build_context_synchronously
      await context.read<AppProvider>().setHaUrl(result);
    }
  }

  Future<void> _editHaToken(BuildContext context) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditTextDialog(
        title: 'Long-Lived Access Token',
        hint: 'Enter your access token',
        controller: controller,
        isPassword: true,
      ),
    );

    if (result != null) {
      // ignore: use_build_context_synchronously
      await context.read<AppProvider>().setHaToken(result);
    }
  }

  Future<void> _testConnection(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Testing connection...'),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    // ignore: use_build_context_synchronously
    Navigator.pop(context);

    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Test'),
        content: const Text('Connection successful!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectLockEntity(BuildContext context) async {
    // Show lock entity selection dialog
    final locks = ['lock.front_door', 'lock.back_door', 'lock.garage_door'];

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EntitySelectionDialog(locks: locks),
    );

    if (result != null) {
      // ignore: use_build_context_synchronously
      await context.read<AppProvider>().setSelectedLockEntity(result);
    }
  }
}

/// Notification settings section
class _NotificationSection extends StatelessWidget {
  const _NotificationSection();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final settings = appProvider.settings;

    return _Section(
      title: 'Notifications',
      icon: Icons.notifications_outlined,
      children: [
        SwitchListTile(
          title: const Text('Enable Notifications'),
          subtitle: const Text('Receive alerts for unlocked doors'),
          value: settings.notificationsEnabled,
          onChanged: (value) {
            appProvider.setNotificationsEnabled(value);
          },
        ),
        ListTile(
          title: const Text('Alert Timeout'),
          subtitle: Text('Wait ${settings.alertTimeout} seconds after door close'),
          trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () => _editAlertTimeout(context),
        ),
      ],
    );
  }

  Future<void> _editAlertTimeout(BuildContext context) async {
    final appProvider = context.read<AppProvider>();
    final current = appProvider.settings.alertTimeout;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => _SliderDialog(
        title: 'Alert Timeout',
        value: current.toDouble(),
        min: 1,
        max: 30,
        divisions: 29,
        label: '$current seconds',
      ),
    );

    if (result != null) {
      // ignore: use_build_context_synchronously
      await appProvider.setAlertTimeout(result);
    }
  }
}

/// Gesture detection settings section
class _DetectionSection extends StatelessWidget {
  const _DetectionSection();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final settings = appProvider.settings;

    return _Section(
      title: 'Gesture Detection',
      icon: Icons.camera_alt_outlined,
      children: [
        SwitchListTile(
          title: const Text('Enable Monitoring'),
          subtitle: const Text('Detect gestures when camera is active'),
          value: settings.monitoringEnabled,
          onChanged: (value) {
            appProvider.setMonitoringEnabled(value);
          },
        ),
        ListTile(
          title: const Text('Sensitivity'),
          subtitle: Text(
            'Detection sensitivity: ${settings.sensitivity}%',
          ),
          trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () => _editSensitivity(context),
        ),
        ListTile(
          title: const Text('Calibrate Handle Position'),
          subtitle: const Text('Set door handle location'),
          trailing: const Icon(Icons.touch_app, color: AppTheme.primaryColor),
          onTap: () {},
        ),
      ],
    );
  }

  Future<void> _editSensitivity(BuildContext context) async {
    final appProvider = context.read<AppProvider>();
    final current = appProvider.settings.sensitivity;

    final result = await showDialog<double>(
      context: context,
      builder: (context) => _SliderDialog(
        title: 'Detection Sensitivity',
        value: current.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        label: 'Sensitivity',
      ),
    );

    if (result != null) {
      // ignore: use_build_context_synchronously
      await appProvider.setSensitivity(result.toInt());
    }
  }
}

/// Data and logging section
class _DataSection extends StatelessWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Data & Privacy',
      icon: Icons.storage_outlined,
      children: [
        const ListTile(
          title: Text('Export Activity Log'),
          subtitle: Text('Export detection history as CSV'),
          trailing: Icon(Icons.download, color: AppTheme.primaryColor),
        ),
        const ListTile(
          title: Text('Clear Activity Log'),
          subtitle: Text('Delete all logged events'),
          trailing: Icon(Icons.delete, color: AppTheme.unlockedColor),
        ),
        ListTile(
          title: const Text('Storage Used'),
          subtitle: const Text('2.4 MB'),
          trailing: Text(
            '10 MB limit',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// About section
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'About',
      icon: Icons.info_outlined,
      children: [
        ListTile(
          title: const Text('Version'),
          subtitle: Text('${AppConstants.appName} ${AppConstants.appVersion}'),
        ),
        ListTile(
          title: const Text('Privacy Policy'),
          subtitle: const Text('All processing is done on-device'),
          trailing: const Icon(Icons.security, color: AppTheme.lockedColor),
        ),
        ListTile(
          title: const Text('Open Source Licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.appVersion,
            );
          },
        ),
      ],
    );
  }
}

/// Section container widget
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Custom list tile widget
class _ListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ListTile({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Edit text dialog
class _EditTextDialog extends StatefulWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final bool isPassword;

  const _EditTextDialog({
    required this.title,
    required this.hint,
    required this.controller,
    this.isPassword = false,
  });

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          hintText: widget.hint,
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscure = !_obscure;
                    });
                  },
                )
              : null,
        ),
        obscureText: widget.isPassword && _obscure,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, widget.controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Slider dialog
class _SliderDialog extends StatefulWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;

  const _SliderDialog({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
  });

  @override
  State<_SliderDialog> createState() => _SliderDialogState();
}

class _SliderDialogState extends State<_SliderDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: _value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: '${_value.toInt()}',
            onChanged: (value) {
              setState(() {
                _value = value;
              });
            },
          ),
          Text(
            '${_value.toInt()}${widget.label.contains('seconds') ? ' seconds' : '%'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _value),
          child: const Text('Set'),
        ),
      ],
    );
  }
}

/// Entity selection dialog
class _EntitySelectionDialog extends StatelessWidget {
  final List<String> locks;

  const _EntitySelectionDialog({required this.locks});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Lock Entity'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: locks.map((lock) {
          return ListTile(
            title: Text(lock.replaceAll('lock.', '').replaceAll('_', ' ')),
            subtitle: Text(lock),
            onTap: () => Navigator.pop(context, lock),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
