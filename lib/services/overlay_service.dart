import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'notification_service.dart';
import 'enhanced_phishing_detector.dart';
import 'realtime_deepfake_detector.dart';

class OverlayService {
  static final OverlayService _instance = OverlayService._();
  factory OverlayService() => _instance;
  OverlayService._();

  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isOverlayActive = false;
  bool _isScanning = false;
  
  final _deepfakeDetector = RealtimeDeepfakeDetector();
  final _phishingDetector = EnhancedPhishingDetector();
  
  // Overlay state
  Offset _floatingButtonPosition = const Offset(100, 300);
  double _floatingButtonSize = 56;
  
  bool get isOverlayActive => _isOverlayActive;
  bool get isScanning => _isScanning;

  Future<void> initialize() async {
    await _deepfakeDetector.initialize();
    await _phishingDetector.initialize();
    print('OverlayService initialized');
  }

  // Check if overlay permission is granted
  Future<bool> hasOverlayPermission() async {
    try {
      return await Permission.systemAlertWindow.isGranted;
    } catch (e) {
      print('Error checking overlay permission: $e');
      return false;
    }
  }

  // Request overlay permission
  Future<bool> requestOverlayPermission() async {
    try {
      return await Permission.systemAlertWindow.request() == PermissionStatus.granted;
    } catch (e) {
      print('Error requesting overlay permission: $e');
      return false;
    }
  }

  // Start the floating overlay
  Future<void> startOverlay({
    required BuildContext context,
    VoidCallback? onScanComplete,
  }) async {
    if (_isOverlayActive) return;
    
    // Check and request permission if needed
    final hasPermission = await hasOverlayPermission();
    if (!hasPermission) {
      _showPermissionDialog(context);
      return;
    }
    
    _isOverlayActive = true;
    
    // Initialize detector if needed
    if (!_deepfakeDetector.isInitialized) {
      await _deepfakeDetector.initialize();
    }
    if (!_phishingDetector.isInitialized) {
      await _phishingDetector.initialize();
    }
    
    // Show the floating button
    _showFloatingButton(context, onScanComplete: onScanComplete);
    
    // Show notification
    await NotificationService().showBackgroundScanNotification(
      title: 'SecureScan Active',
      body: 'Tap the shield icon to scan any screen',
    );
    
    print('Overlay started');
  }

  // Stop the overlay
  Future<void> stopOverlay() async {
    _isOverlayActive = false;
    _hideFloatingButton();
    await NotificationService().cancelBackgroundScanNotification();
    print('Overlay stopped');
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Overlay Permission Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.security, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('SecureScan needs permission to display an overlay icon.'),
            const SizedBox(height: 8),
            Text(
              'This allows you to scan content from any app, including Instagram Reels.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showFloatingButton(BuildContext context, {VoidCallback? onScanComplete}) {
    showOverlay(
      (context, progress) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        return Positioned(
          left: _floatingButtonPosition.dx.clamp(0.0, screenWidth - _floatingButtonSize),
          top: _floatingButtonPosition.dy.clamp(0.0, screenHeight - _floatingButtonSize),
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _floatingButtonPosition = Offset(
                  (_floatingButtonPosition.dx + details.delta.dx).clamp(0.0, screenWidth - _floatingButtonSize),
                  (_floatingButtonPosition.dy + details.delta.dy).clamp(0.0, screenHeight - _floatingButtonSize),
                );
              });
            },
            onTap: () async {
              if (_isScanning) return;
              await _performScan(context, onScanComplete: onScanComplete);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _floatingButtonSize,
              height: _floatingButtonSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade700,
                    Colors.blue.shade900,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isScanning
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    )
                  : const Icon(
                      Icons.shield,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          ),
        );
      },
      duration: Duration.zero,
    );
  }

  void setState(VoidCallback fn) {
    // Force rebuild of overlay by showing a dummy notification
    // This is a workaround since we can't directly rebuild the overlay
  }

  void _hideFloatingButton() {
    // Dismiss all overlays
    OverlaySupportEntryEntry?.call();
  }

  Future<void> _performScan(BuildContext context, {VoidCallback? onScanComplete}) async {
    if (_isScanning) return;
    
    _isScanning = true;
    
    try {
      // Show scanning indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanning...')),
      );
      
      // Take screenshot
      final Uint8List? screenshot = await _screenshotController.capture(
        pixelRatio: 1.0,
      );
      
      if (screenshot == null) {
        _showResult(context, 'Failed to capture screenshot', isError: true);
        return;
      }
      
      // Detect faces and deepfake
      final detectionResult = await _deepfakeDetector.detectFrame(screenshot);
      
      // Show result
      await _showDeepfakeResult(context, detectionResult);
      
      // Call completion callback
      onScanComplete?.call();
      
    } catch (e) {
      print('Scan error: $e');
      _showResult(context, 'Scan failed: $e', isError: true);
    } finally {
      _isScanning = false;
    }
  }

  Future<void> _showDeepfakeResult(
    BuildContext context,
    DeepfakeDetectionResult result,
  ) async {
    final color = result.isDeepfake ? Colors.red : Colors.green;
    final icon = result.isDeepfake ? Icons.warning : Icons.check_circle;
    final title = result.isDeepfake ? '⚠️ Potential Deepfake' : '✅ Appears Authentic';
    final confidence = (result.confidence * 100).toStringAsFixed(1);
    
    // Show overlay notification
    showOverlayNotification(
      Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Confidence: $confidence%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (result.hasFace) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Face detected in image',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      duration: const Duration(seconds: 5),
    );
    
    // Also show notification
    await NotificationService().showDeepfakeResult(
      isDeepfake: result.isDeepfake,
      confidence: result.confidence,
      imageSource: 'overlay_scan',
    );
  }

  void _showResult(BuildContext context, String message, {bool isError = false}) {
    showOverlayNotification(
      Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isError ? Colors.red : Colors.green).withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 3),
    );
  }

  // Scan a URL (from clipboard or input)
  Future<void> scanUrl(String url, {BuildContext? context}) async {
    if (!_phishingDetector.isInitialized) {
      await _phishingDetector.initialize();
    }
    
    final result = await _phishingDetector.detect(url);
    
    // Show notification
    await NotificationService().showPhishingResult(
      isPhishing: result.isPhishing,
      url: url,
      riskLevel: result.riskLevel.name,
    );
  }

  // Save scan result to history
  Future<void> saveToHistory({
    required String type,
    required String content,
    required String result,
    required double confidence,
    Map<String, dynamic>? details,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uuid = const Uuid().v4();
    
    final scanData = {
      'id': uuid,
      'type': type,
      'content': content,
      'result': result,
      'confidence': confidence,
      'details': details,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    // Get existing history
    final historyJson = prefs.getStringList('scan_history') ?? [];
    historyJson.add(jsonEncode(scanData));
    
    // Keep only last 100 entries
    if (historyJson.length > 100) {
      historyJson.removeAt(0);
    }
    
    await prefs.setStringList('scan_history', historyJson);
  }

  void dispose() {
    _isOverlayActive = false;
    _isScanning = false;
  }
}

// Import for jsonEncode
import 'dart:convert' as convert;
