import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'core/logger.dart';
import 'core/analytics.dart';
import 'core/crash_reporter.dart';
import 'features/deepfake/deepfake_detector_service.dart';
import 'features/deepfake/deepfake_scan_page.dart';
import 'features/phishing/phishing_detector_service.dart';
import 'features/phishing/phishing_scan_page.dart';
import 'features/history/history_page.dart';
import 'features/settings/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _initializeServices();

  runApp(const SecureScanApp());
}

void _initializeServices() async {
  appLogger.configure(enableConsole: true, enableFile: false, minLevel: LogLevel.debug);
  crashReporter.initialize();
  analyticsService.setConsent(true);
  analyticsService.initialize();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await HistoryDatabase.instance.init();
  appLogger.i('SecureScan initialized');
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'dailyDatabaseUpdate': await BackgroundScanner.updateDatabase(); break;
      case 'clipboardMonitor': await BackgroundScanner.monitorClipboard(inputData?['url']); break;
    }
    return Future.value(true);
  });
}

class SecureScanApp extends StatelessWidget {
  const SecureScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade700, primary: Colors.blue.shade700, secondary: Colors.blue.shade500),
        useMaterial3: true,
        appBarTheme: AppBarTheme(centerTitle: true, backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        cardTheme: CardTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true, fillColor: Colors.grey.shade50,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0;
  bool _backgroundEnabled = false;
  bool _notificationsEnabled = true;

  final List<Widget> _pages = [const DeepfakeScanPage(), const PhishingScanPage(), const HistoryPage(), const SettingsPage()];
  final List<String> _titles = ['Deepfake Detection', 'Phishing Detection', 'Scan History', 'Settings'];

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedTab]), actions: [
        if (_selectedTab == 0 || _selectedTab == 1)
          IconButton(icon: const Icon(Icons.history), onPressed: () => setState(() => _selectedTab = 2)),
      ]),
      body: _pages[_selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.face), label: 'Deepfake'),
          NavigationDestination(icon: Icon(Icons.link), label: 'Phishing'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class BackgroundScanner {
  static final DeepfakeDetectorService _deepfakeDetector = DeepfakeDetectorService();
  static final PhishingDetectorService _phishingDetector = PhishingDetectorService();

  static Future<void> initializeDetectors() async {
    await _deepfakeDetector.loadModel();
    await _phishingDetector.initialize();
  }

  static Future<void> updateDatabase() async => appLogger.i('Updating local database');

  static Future<void> monitorClipboard(String? url) async {
    if (url != null) {
      final result = await _phishingDetector.detect(url);
      if (result.isPhishing) appLogger.w('Suspicious URL detected: $url');
    }
  }
}

class HistoryDatabase {
  static final HistoryDatabase instance = HistoryDatabase._();
  Database? _database;

  HistoryDatabase._();

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/secure_scan_history.db';
    _database = await openDatabase(path, version: 1, onCreate: (db, version) {
      db.execute('CREATE TABLE scans (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, content TEXT NOT NULL, result TEXT NOT NULL, confidence REAL NOT NULL, details TEXT, timestamp INTEGER NOT NULL)');
    });
  }

  Future<void> insertScan({required String type, required String content, required String result, required double confidence, String? details}) async {
    if (_database == null) await init();
    await _database!.insert('scans', {'type': type, 'content': content, 'result': result, 'confidence': confidence, 'details': details, 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }

  Future<List<ScanHistoryItem>> getAllScans() async {
    if (_database == null) await init();
    final maps = await _database!.query('scans', orderBy: 'timestamp DESC', limit: 100);
    return maps.map((map) => ScanHistoryItem.fromMap(map)).toList();
  }

  Future<void> deleteScan(int id) async {
    if (_database == null) await init();
    await _database!.delete('scans', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearHistory() async {
    if (_database == null) await init();
    await _database!.delete('scans');
  }
}

class ScanHistoryItem {
  final int id;
  final String type;
  final String content;
  final String result;
  final double confidence;
  final String? details;
  final DateTime timestamp;

  ScanHistoryItem({required this.id, required this.type, required this.content, required this.result, required this.confidence, this.details, required this.timestamp});

  factory ScanHistoryItem.fromMap(Map<String, dynamic> map) {
    return ScanHistoryItem(
      id: map['id'],
      type: map['type'],
      content: map['content'],
      result: map['result'],
      confidence: map['confidence'].toDouble(),
      details: map['details'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

class SecureScanNotifications {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(settings);
  }

  static Future<void> showScanCompleteNotification(String title, String body) async {
    const notification = NotificationDetails(android: AndroidNotificationDetails('scan_results', 'Scan Results', importance: Importance.high), iOS: DarwinNotificationDetails());
    await _notifications.show(0, title, body, notification);
  }
}
