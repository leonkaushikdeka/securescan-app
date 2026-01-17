import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../../core/analytics.dart';
import '../../core/crash_reporter.dart';
import '../../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _backgroundEnabled = false;
  bool _notificationsEnabled = true;
  bool _clipboardMonitorEnabled = false;
  bool _analyticsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundEnabled = prefs.getBool('backgroundEnabled') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _clipboardMonitorEnabled = prefs.getBool('clipboardMonitorEnabled') ?? false;
      _analyticsEnabled = prefs.getBool('analyticsEnabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _toggleBackground(bool value) async {
    setState(() => _backgroundEnabled = value);
    await _saveSetting('backgroundEnabled', value);

    if (value) {
      await Workmanager().registerPeriodicTask(
        'dailyDatabaseUpdate',
        'dailyDatabaseUpdate',
        frequency: const Duration(hours: 24),
      );
    } else {
      await Workmanager().cancelByTag('dailyDatabaseUpdate');
    }

    analyticsService.logSettingsChange('backgroundEnabled', value);
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _saveSetting('notificationsEnabled', value);
    analyticsService.logSettingsChange('notificationsEnabled', value);
  }

  Future<void> _toggleClipboardMonitor(bool value) async {
    setState(() => _clipboardMonitorEnabled = value);
    await _saveSetting('clipboardMonitorEnabled', value);
    analyticsService.logSettingsChange('clipboardMonitorEnabled', value);
  }

  Future<void> _toggleAnalytics(bool value) async {
    setState(() => _analyticsEnabled = value);
    await _saveSetting('analyticsEnabled', value);
    analyticsService.setConsent(value);
    analyticsService.logSettingsChange('analyticsEnabled', value);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Protection Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Background Protection'),
                subtitle: const Text('Daily database updates'),
                value: _backgroundEnabled,
                onChanged: _toggleBackground,
              ),
              SwitchListTile(
                title: const Text('Notifications'),
                subtitle: const Text('Alert when threats detected'),
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
              SwitchListTile(
                title: const Text('Clipboard Monitor'),
                subtitle: const Text('Scan URLs copied to clipboard'),
                value: _clipboardMonitorEnabled,
                onChanged: _toggleClipboardMonitor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Privacy & Data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Analytics'),
                subtitle: const Text('Help improve detection'),
                value: _analyticsEnabled,
                onChanged: _toggleAnalytics,
              ),
              ListTile(
                title: const Text('Clear Scan History'),
                subtitle: const Text('Delete all stored scan records'),
                onTap: () async {
                  await HistoryDatabase.instance.clearHistory();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('History cleared')),
                    );
                  }
                  analyticsService.logSettingsChange('clearHistory', true);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('About', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              const ListTile(
                title: Text('SecureScan'),
                subtitle: Text('Version 1.0.0'),
              ),
              const Divider(),
              ListTile(
                title: const Text('Detection Methods'),
                subtitle: const Text('Deepfake: ML + Image Forensics\nPhishing: 22+ pattern detection'),
                isThreeLine: true,
              ),
              const Divider(),
              ListTile(
                title: const Text('Privacy Policy'),
                subtitle: const Text('All analysis runs locally'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Privacy Policy'),
                      content: const Text(
                        'SecureScan processes all data locally on your device.\n\n'
                        'No images, URLs, or personal data are sent to any server.\n\n'
                        'We do not collect, store, or share any user data.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('Crash Reports'),
                subtitle: Text('${crashReporter.getCrashCount()} crashes logged'),
                onTap: () {
                  final summary = analyticsService.getAnalyticsSummary();
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Analytics Summary'),
                      content: Text(
                        'Session: ${summary['sessionId'] ?? 'N/A'}\n'
                        'Total Events: ${summary['totalEvents']}\n'
                        'Crashes: ${crashReporter.getCrashCount()}',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '🔒 100% Local Processing\nNo data leaves your device',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}
