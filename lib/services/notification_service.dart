import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  static const String _channelId = 'secure_scan_channel';
  static const String _channelIdBackground = 'background_scan_channel';
  
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Android settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _notifications.initialize(settings);
      
      // Create notification channels
      await _createChannels();
      
      _isInitialized = true;
      print('NotificationService initialized');
    } catch (e) {
      print('NotificationService initialization failed: $e');
    }
  }

  Future<void> _createChannels() async {
    // Main threat alert channel
    const channel1 = AndroidNotificationChannel(
      _channelId,
      'SecureScan Alerts',
      description: 'Threat detection alerts and scan results',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      showBadge: true,
    );
    
    // Background scan channel (lower importance)
    const channel2 = AndroidNotificationChannel(
      _channelIdBackground,
      'Background Scanning',
      description: 'Background scan updates and database sync',
      importance: Importance.low,
      priority: Priority.low,
      enableLights: false,
      enableVibration: false,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel1);
    
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel2);
    
    print('Notification channels created');
  }

  // Show deepfake detection result
  Future<void> showDeepfakeResult({
    required bool isDeepfake,
    required double confidence,
    required String imageSource,
  }) async {
    if (!_isInitialized) await initialize();
    
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notificationsEnabled') ?? true)) return;
    
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'SecureScan Alerts',
      channelDescription: 'Threat detection alerts and scan results',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        badgeNumber: 1,
        subtitle: 'Deepfake Detection',
      ),
    );
    
    final title = isDeepfake ? '⚠️ DEEPFAKE DETECTED' : '✅ Image Appears Authentic';
    final body = isDeepfake
        ? 'Confidence: ${(confidence * 100).toStringAsFixed(1)}%\nPotential deepfake content found.'
        : 'Confidence: ${(confidence * 100).toStringAsFixed(1)}%\nNo deepfake indicators detected.';
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }

  // Show phishing detection result
  Future<void> showPhishingResult({
    required bool isPhishing,
    required String url,
    required String riskLevel,
  }) async {
    if (!_isInitialized) await initialize();
    
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notificationsEnabled') ?? true)) return;
    
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'SecureScan Alerts',
      channelDescription: 'Threat detection alerts and scan results',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        badgeNumber: 1,
        subtitle: 'Phishing Detection',
      ),
    );
    
    final title = isPhishing 
        ? '🚨 PHISHING LINK DETECTED' 
        : '✅ URL Appears Safe';
    final body = isPhishing
        ? 'Risk: $riskLevel\n$url'
        : 'No threats found in URL';
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }

  // Background scan notification
  Future<void> showBackgroundScanNotification({
    required String title,
    required String body,
    int progress = -1,
  }) async {
    if (!_isInitialized) await initialize();
    
    final androidDetails = AndroidNotificationDetails(
      _channelIdBackground,
      'Background Scanning',
      channelDescription: 'Background scan updates and database sync',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: progress >= 0,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
      onlyAlertOnce: true,
      icon: '@mipmap/ic_launcher',
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        badgeNumber: 0,
        subtitle: 'Background Scanning',
      ),
    );
    
    await _notifications.show(
      999,
      title,
      body,
      details,
    );
  }

  // Update background scan progress
  Future<void> updateBackgroundScanProgress(int progress, String status) async {
    await showBackgroundScanNotification(
      title: 'SecureScan Background Scan',
      body: status,
      progress: progress,
    );
  }

  // Cancel background scan notification
  Future<void> cancelBackgroundScanNotification() async {
    await _notifications.cancel(999);
  }

  // Show threat alert for clipboard monitoring
  Future<void> showClipboardThreatAlert({
    required String url,
    required String riskLevel,
  }) async {
    if (!_isInitialized) await initialize();
    
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'SecureScan Alerts',
      channelDescription: 'Threat detection alerts and scan results',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      alertBehavior: NotificationAlertBehavior.silenced,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        badgeNumber: 1,
        subtitle: 'Clipboard Threat Alert',
      ),
    );
    
    await _notifications.show(
      888,
      '🚨 Clipboard Threat Detected',
      'Risk: $riskLevel\nURL: $url',
      details,
    );
  }

  // Schedule daily scan reminder
  Future<void> scheduleDailyScanReminder() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'SecureScan Alerts',
      channelDescription: 'Threat detection alerts and scan results',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    
    // Show immediately for demo - in production use timezone plugin
    await _notifications.show(
      777,
      '🛡️ Daily Security Check',
      'Take a moment to scan any suspicious content you\'ve encountered today.',
      details,
    );
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // Request notification permission (for iOS)
  Future<bool> requestPermission() async {
    try {
      final settings = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      
      return settings?.alert ?? false;
    } catch (e) {
      print('Notification permission error: $e');
      return false;
    }
  }

  void dispose() {
    _isInitialized = false;
  }
}
