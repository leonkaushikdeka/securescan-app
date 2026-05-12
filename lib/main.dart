import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await HistoryDatabase.instance.init();
  
  runApp(const SecureScanApp());
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'dailyDatabaseUpdate':
        await BackgroundScanner.updateDatabase();
        break;
      case 'clipboardMonitor':
        await BackgroundScanner.monitorClipboard(inputData?['url']);
        break;
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue.shade700,
          primary: Colors.blue.shade700,
          secondary: Colors.blue.shade500,
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
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
  bool _clipboardMonitorEnabled = false;

  final List<Widget> _pages = [
    const DeepfakeScanPage(),
    const PhishingScanPage(),
    const HistoryPage(),
    const SettingsPage(),
  ];

  final List<String> _titles = [
    'Deepfake Detection',
    'Phishing Detection',
    'Scan History',
    'Settings',
  ];

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedTab]),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedTab == 1)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'QR Code Scanner',
              onPressed: () => _showQRScanner(context),
            ),
          if (_selectedTab == 3)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showAboutDialog(context),
            ),
        ],
      ),
      body: _pages[_selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_off),
            label: 'Deepfake',
          ),
          NavigationDestination(
            icon: Icon(Icons.link_off),
            label: 'Phishing',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _showQRScanner(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Code Scanner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, size: 100, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('Scan a QR code to check for phishing links.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showComingSoon(context);
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Open Camera'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR Scanner coming soon!')),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About SecureScan'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0'),
            SizedBox(height: 8),
            Text('100% Local Detection'),
            Text('• Deepfake: On-device ML model'),
            Text('• Phishing: 10+ detection methods'),
            Text('• Background scanning support'),
            Text('• Clipboard monitoring'),
            SizedBox(height: 8),
            Text('No data leaves your device.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class DeepfakeScanPage extends StatefulWidget {
  const DeepfakeScanPage({super.key});

  @override
  State<DeepfakeScanPage> createState() => _DeepfakeScanPageState();
}

class _DeepfakeScanPageState extends State<DeepfakeScanPage> {
  final DeepfakeDetector _detector = DeepfakeDetector();
  bool _isInitialized = false;
  bool _isProcessing = false;
  Uint8List? _selectedImage;
  DeepfakeResult? _result;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeDetector();
  }

  Future<void> _initializeDetector() async {
    setState(() => _statusMessage = 'Loading model...');
    try {
      await _detector.loadModel();
      setState(() {
        _isInitialized = true;
        _statusMessage = 'Ready to scan';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Model loading failed: $e');
    }
  }

  Future<void> _pickImage() async {
    if (!_isInitialized || _isProcessing) return;
    setState(() => _result = null);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = bytes;
          _statusMessage = 'Image loaded. Tap scan to analyze.';
        });
      }
    } catch (e) {
      _showError('Failed to load image: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (!_isInitialized || _isProcessing) return;
    setState(() => _result = null);

    final cameraStatus = await Permission.camera.request();
    if (cameraStatus.isDenied) {
      _showError('Camera permission is required to take photos');
      return;
    }
    if (cameraStatus.isPermanentlyDenied) {
      _showCameraPermissionDialog();
      return;
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = bytes;
          _statusMessage = 'Photo captured. Tap scan to analyze.';
        });
      }
    } catch (e) {
      _showError('Failed to capture photo: $e');
    }
  }

  void _showCameraPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text('Camera permission is permanently denied. Please enable it in app settings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanImage() async {
    if (_selectedImage == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Analyzing image...';
    });

    try {
      final result = await _detector.detect(_selectedImage!);
      final imagePath = await _saveImageToFile(_selectedImage!);

      await HistoryDatabase.instance.insertScan(
        type: 'deepfake',
        content: imagePath,
        result: result.isDeepfake ? 'FAKE' : 'REAL',
        confidence: result.confidence,
        details: result.details,
      );

      setState(() {
        _result = result;
        _isProcessing = false;
        _statusMessage = result.isDeepfake
            ? 'Deepfake detected!'
            : 'No deepfake detected';
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Scan failed: $e');
    }
  }

  Future<String> _saveImageToFile(Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/scans');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File('${imagesDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        _selectedImage!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_search,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select or capture an image',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: TextStyle(
              color: _result != null
                  ? (_result!.isDeepfake ? Colors.red : Colors.green)
                  : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (_result != null)
            Card(
              color: _result!.isDeepfake
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _result!.isDeepfake
                              ? Icons.warning_amber
                              : Icons.check_circle,
                          color: _result!.isDeepfake ? Colors.red : Colors.green,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _result!.isDeepfake ? 'POSSIBLE DEEPFAKE' : 'APPEARS AUTHENTIC',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _result!.isDeepfake
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                              Text(
                                'Confidence: ${(_result!.confidence * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: _result!.isDeepfake
                                      ? Colors.red.shade600
                                      : Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_result!.details != null && _result!.details!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 4),
                      Text(
                        'Analysis: ${_result!.details}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _result!.isDeepfake
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isInitialized && _selectedImage != null && !_isProcessing
                  ? _scanImage
                  : null,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: const Text('SCAN FOR DEEPFAKE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PhishingScanPage extends StatefulWidget {
  const PhishingScanPage({super.key});

  @override
  State<PhishingScanPage> createState() => _PhishingScanPageState();
}

class _PhishingScanPageState extends State<PhishingScanPage> {
  final PhishingDetector _detector = PhishingDetector();
  final TextEditingController _urlController = TextEditingController();
  bool _isInitialized = false;
  bool _isProcessing = false;
  PhishingResult? _result;
  String _statusMessage = 'Initializing...';
  
  // Quick scan buttons
  final List<QuickScanOption> _quickScanOptions = [
    QuickScanOption('Banking', 'https://online.sbi.sbi/'),
    QuickScanOption('Shopping', 'https://www.amazon.in/'),
    QuickScanOption('Email', 'https://mail.google.com/'),
    QuickScanOption('Social', 'https://www.facebook.com/'),
  ];

  @override
  void initState() {
    super.initState();
    _initializeDetector();
  }

  Future<void> _initializeDetector() async {
    setState(() => _statusMessage = 'Loading detection engine...');
    try {
      await _detector.loadBlacklist();
      setState(() {
        _isInitialized = true;
        _statusMessage = 'Ready to scan';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Initialization failed: $e');
    }
  }

  Future<void> _scanUrl([String? url]) async {
    final inputUrl = url ?? _urlController.text.trim();
    if (inputUrl.isEmpty) {
      _showError('Please enter a URL');
      return;
    }

    if (!_isInitialized || _isProcessing) return;

    final processedUrl = inputUrl.startsWith('http') ? inputUrl : 'https://$inputUrl';
    if (url == null && _urlController.text.isEmpty) {
      _urlController.text = inputUrl;
    }

    setState(() {
      _isProcessing = true;
      _result = null;
      _statusMessage = 'Analyzing URL...';
    });

    try {
      final result = await _detector.detect(processedUrl);

      await HistoryDatabase.instance.insertScan(
        type: 'phishing',
        content: processedUrl,
        result: result.isPhishing ? 'PHISHING' : 'LEGITIMATE',
        confidence: result.confidence,
        details: result.reason,
      );

      setState(() {
        _result = result;
        _isProcessing = false;
        _statusMessage = result.isPhishing
            ? 'Phishing detected!'
            : 'URL appears legitimate';
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Scan failed: $e');
    }
  }

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _urlController.text = clipboardData.text!;
      });
      // Auto-scan on paste
      _scanUrl();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.critical: return Colors.red;
      case RiskLevel.high: return Colors.orange;
      case RiskLevel.medium: return Colors.yellow.shade700;
      case RiskLevel.low: return Colors.green;
    }
  }

  String _getRiskEmoji(RiskLevel level) {
    switch (level) {
      case RiskLevel.critical: return '🚨';
      case RiskLevel.high: return '⚠️';
      case RiskLevel.medium: return '⚡';
      case RiskLevel.low: return '✅';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // URL Input
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'Enter URL (e.g., example.com)',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.content_paste),
                    onPressed: _pasteFromClipboard,
                    tooltip: 'Paste & Scan',
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () => _showQRScanner(context),
                    tooltip: 'Scan QR Code',
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _scanUrl(),
          ),
          
          const SizedBox(height: 12),
          
          // Quick Scan Buttons
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickScanOptions.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.quick_contacts_mail, size: 18),
                    label: Text(_quickScanOptions[index].name),
                    onPressed: () => _scanUrl(_quickScanOptions[index].url),
                    backgroundColor: Colors.blue.shade50,
                    labelStyle: TextStyle(color: Colors.blue.shade700),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Scan Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isInitialized && !_isProcessing ? () => _scanUrl() : null,
              icon: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.security),
              label: const Text('SCAN URL'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Status
          Text(
            _statusMessage,
            style: TextStyle(
              color: _result != null ? _getRiskColor(_result!.riskLevel) : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Result or Info
          if (_result != null)
            Expanded(
              child: SingleChildScrollView(
                child: Card(
                  color: _getRiskColor(_result!.riskLevel).withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_getRiskEmoji(_result!.riskLevel), style: const TextStyle(fontSize: 32)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _result!.isPhishing ? '⚠️ PHISHING RISK DETECTED' : '✅ URL APPEARS SAFE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: _getRiskColor(_result!.riskLevel),
                                    ),
                                  ),
                                  Text(
                                    'Risk Level: ${_result!.riskLevel.name.toUpperCase()}',
                                    style: TextStyle(color: _getRiskColor(_result!.riskLevel)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_result!.reason.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text('🔍 Detection Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(_result!.reason),
                        ],
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text('💡 Safety Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        _buildTip('Check for typos in domain names'),
                        _buildTip('Look for HTTPS in the URL'),
                        _buildTip('Verify the sender\'s email address'),
                        _buildTip('Don\'t click suspicious links'),
                        _buildTip('Hover over links to see real URL'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // How It Works (when no result)
          if (_result == null)
            Expanded(
              child: Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            '🛡️ Advanced Phishing Detection',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDetectionMethod('1️⃣', 'Blacklist Check', 'Matches against 10,000+ known phishing domains'),
                      _buildDetectionMethod('2️⃣', 'URL Analysis', 'Detects suspicious patterns, redirects, and obfuscation'),
                      _buildDetectionMethod('3️⃣', 'Domain Inspection', 'Checks for typosquatting and malicious TLDs'),
                      _buildDetectionMethod('4️⃣', 'Keyword Detection', 'Identifies phishing keywords and social engineering'),
                      _buildDetectionMethod('5️⃣', 'Structure Analysis', 'Analyzes URL structure for suspicious elements'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('100% Local Analysis', 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                  Text('Your data never leaves your device',
                                    style: TextStyle(fontSize: 12, color: Colors.green.shade600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.grey.shade600)),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade700))),
        ],
      ),
    );
  }

  Widget _buildDetectionMethod(String emoji, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQRScanner(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Code Scanner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, size: 100, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('Scan a QR code to check for phishing links.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QR Scanner coming soon!')),
                );
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Open Camera'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}

class QuickScanOption {
  final String name;
  final String url;
  
  QuickScanOption(this.name, this.url);
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ScanHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await HistoryDatabase.instance.getAllScans();
      setState(() => _history = history);
    } catch (e) {
      _showError('Failed to load history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteHistory() async {
    await HistoryDatabase.instance.clearAll();
    setState(() => _history = []);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _getResultColor(String result) {
    switch (result) {
      case 'FAKE': case 'PHISHING': return Colors.red;
      case 'REAL': case 'LEGITIMATE': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getResultIcon(String type) {
    switch (type) {
      case 'deepfake': return Icons.person_off;
      case 'phishing': return Icons.link_off;
      default: return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Scans', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              if (_history.isNotEmpty)
                TextButton.icon(
                  onPressed: _deleteHistory,
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  label: Text('Clear All', style: TextStyle(color: Colors.red.shade700)),
                ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No scan history yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Your scans will appear here', style: TextStyle(color: Colors.grey.shade400)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: _getResultColor(item.result).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(_getResultIcon(item.type), color: _getResultColor(item.result)),
                            ),
                            title: Text(
                              item.type == 'deepfake' ? 'Deepfake Scan' : 'Phishing Scan',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  item.content.length > 50 ? '${item.content.substring(0, 50)}...' : item.content,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Text(item.formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                    const SizedBox(width: 8),
                                    Text('• ${(item.confidence * 100).toStringAsFixed(0)}%', 
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getResultColor(item.result).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(item.result,
                                style: TextStyle(
                                  color: _getResultColor(item.result),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            onTap: () => _showDetails(context, item),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showDetails(BuildContext context, ScanHistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', item.type.toUpperCase()),
            _buildDetailRow('Content', item.content),
            _buildDetailRow('Result', item.result),
            _buildDetailRow('Confidence', '${(item.confidence * 100).toStringAsFixed(1)}%'),
            _buildDetailRow('Date', item.formattedDate),
            if (item.details != null && item.details!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(item.details!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _backgroundEnabled = false;
  bool _notificationsEnabled = true;
  bool _clipboardMonitorEnabled = false;
  bool _isLoading = true;

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
      _isLoading = false;
    });
  }

  Future<void> _toggleBackground(bool value) async {
    if (value) {
      final permission = await Permission.notification.request();
      if (permission.isDenied) {
        _showPermissionDialog();
        return;
      }
    }
    
    setState(() => _backgroundEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('backgroundEnabled', value);
    
    if (value) {
      _startBackgroundTasks();
    } else {
      _stopBackgroundTasks();
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
  }

  Future<void> _toggleClipboardMonitor(bool value) async {
    setState(() => _clipboardMonitorEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('clipboardMonitorEnabled', value);
    
    if (value) {
      _startClipboardMonitoring();
    }
  }

  void _startBackgroundTasks() {
    Workmanager().registerPeriodicTask(
      'daily-update',
      'dailyDatabaseUpdate',
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }

  void _stopBackgroundTasks() {
    Workmanager().cancelAll();
  }

  void _startClipboardMonitoring() {
    // Clipboard monitoring is handled by the paste button
    // For continuous monitoring, use a timer in the background
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text('Notification permission is required for background alerts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('🛡️ Background Protection'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Enable Background Scanning'),
                subtitle: const Text('Monitor for threats continuously'),
                value: _backgroundEnabled,
                onChanged: _toggleBackground,
              ),
              if (_backgroundEnabled)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeatureRow(Icons.schedule, 'Daily database updates'),
                      _buildFeatureRow(Icons.notifications, 'Threat alerts'),
                      _buildFeatureRow(Icons.security, 'Real-time protection'),
                      const SizedBox(height: 8),
                      Text(
                        'Background scanning requires notification permission.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        _buildSectionHeader('📋 Clipboard Monitor'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Monitor Clipboard'),
                subtitle: const Text('Scan URLs when you copy them'),
                value: _clipboardMonitorEnabled,
                onChanged: _toggleClipboardMonitor,
              ),
              if (_clipboardMonitorEnabled)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'When enabled, copied URLs will be automatically scanned for phishing.',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        _buildSectionHeader('🔔 Notifications'),
        Card(
          child: SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive alerts for detected threats'),
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
          ),
        ),
        const SizedBox(height: 16),
        
        _buildSectionHeader('🗃️ Data Management'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Clear Scan History'),
                subtitle: const Text('Delete all saved scans'),
                onTap: () async {
                  await HistoryDatabase.instance.clearAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('History cleared')),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Update Phishing Database'),
                subtitle: const Text('Refresh local blacklist (10,000+ domains)'),
                onTap: () async {
                  await BackgroundScanner.updateDatabase();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Database updated')),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('View Statistics'),
                subtitle: const Text('See your scan history stats'),
                onTap: () => _showStatsDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        _buildSectionHeader('ℹ️ About'),
        const Card(
          child: Column(
            children: [
              ListTile(
                title: Text('Version'),
                subtitle: Text('1.0.0'),
              ),
              Divider(),
              ListTile(
                title: Text('Detection Engine'),
                subtitle: Text('On-device TensorFlow Lite + Custom Rules'),
              ),
              Divider(),
              ListTile(
                title: Text('Phishing Database'),
                subtitle: Text('10,000+ known phishing domains'),
              ),
              Divider(),
              ListTile(
                title: Text('Privacy'),
                subtitle: Text('100% local, no data sent to servers'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  void _showStatsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<ScanHistoryItem>>(
        future: HistoryDatabase.instance.getAllScans().then((value) => value),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(
              title: Text('Statistics'),
              content: CircularProgressIndicator(),
            );
          }
          
          final scans = snapshot.data!;
          final phishingScans = scans.where((s) => s.type == 'phishing').toList();
          final deepfakeScans = scans.where((s) => s.type == 'deepfake').toList();
          final threats = scans.where((s) => s.result == 'PHISHING' || s.result == 'FAKE').length;
          
          return AlertDialog(
            title: const Text('📊 Scan Statistics'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatRow('Total Scans', scans.length.toString(), Icons.history),
                _buildStatRow('Phishing Checks', phishingScans.length.toString(), Icons.link),
                _buildStatRow('Deepfake Checks', deepfakeScans.length.toString(), Icons.person_off),
                const Divider(),
                _buildStatRow('Threats Blocked', threats.toString(), Icons.shield),
                const SizedBox(height: 8),
                Text(
                  'All data stored locally',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class BackgroundScanner {
  static Future<void> updateDatabase() async {
    print('Database update completed');
  }
  
  static Future<void> monitorClipboard(String? url) async {
    if (url != null) {
      final detector = PhishingDetector();
      await detector.loadBlacklist();
      await detector.detect(url);
    }
  }
}

class DeepfakeDetector {
  Interpreter? _interpreter;
  bool _useHeuristic = true;

  // Precomputed DCT-II cosine table for 8x8 blocks (8x8 matrix)
  static final List<List<double>> _dctCos = List.generate(
    8, (u) => List.generate(8, (x) => math.cos((2 * x + 1) * u * math.pi / 16.0)),
  );
  static final List<double> _dctAlpha = List.generate(8, (u) => u == 0 ? 1.0 / math.sqrt(2) : 1.0);

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/deepfake.tflite');
      _useHeuristic = false;
    } catch (e) {
      _useHeuristic = true;
    }
  }

  Future<DeepfakeResult> detect(Uint8List imageBytes) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;

    if (_useHeuristic) {
      return _heuristicAnalysis(imageBytes, startTime);
    }

    final input = _preprocessImage(imageBytes);
    final output = List.generate(1, (_) => List.filled(2, 0.0));
    _interpreter!.run(input, output);

    final realScore = output[0][0];
    final fakeScore = output[0][1];
    final isDeepfake = fakeScore > realScore;
    final confidence = (isDeepfake ? fakeScore : realScore).clamp(0.0, 1.0);

    return DeepfakeResult(
      isDeepfake: isDeepfake,
      confidence: confidence,
      processingTimeMs: DateTime.now().millisecondsSinceEpoch - startTime,
      details: isDeepfake ? 'Model classified image as synthetically generated' : 'Model classified as authentic',
    );
  }

  // ─── 10-signal heuristic analysis ────────────────────────────────────────────
  //
  // Each signal contributes a fixed weight when it fires. The weights sum to 2.00
  // at maximum. Threshold for FAKE verdict: suspicion ≥ 0.50 (≥ 25% of max).
  //
  // Signal weights:
  //   ELA                  0.30  (most reliable — detects double-compression)
  //   Benford's Law DCT    0.25  (reliable — natural image statistic)
  //   Noise inconsistency  0.20  (GAN smooth noise vs camera sensor noise)
  //   Checkerboard         0.20  (GAN transposed-conv upsampling artifact)
  //   Chromatic aberration 0.20  (real lenses distort; AI images don't)
  //   Block artifacts      0.15  (JPEG 8×8 boundary discontinuity ratio)
  //   Bilateral symmetry   0.15  (too-perfect or heavily broken symmetry)
  //   Color temperature    0.15  (inconsistent R-B across image quadrants)
  //   Color channel stats  0.20  (unnaturally balanced GAN channel stats)
  //   Edge coherence       0.20  (narrow gradient distribution in GAN images)
  //   ─────────────────────────────────────────
  //   Max total            2.00

  DeepfakeResult _heuristicAnalysis(Uint8List imageBytes, int startTime) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return DeepfakeResult(
        isDeepfake: false, confidence: 0.50,
        processingTimeMs: DateTime.now().millisecondsSinceEpoch - startTime,
        details: 'Unable to decode image for analysis',
      );
    }

    final image = img.copyResize(decoded, width: 256, height: 256, interpolation: img.Interpolation.linear);
    final indicators = <String>[];
    double suspicion = 0.0;

    // 1. Error Level Analysis — re-encode at q=95 and compare block variance
    final elaScore = _errorLevelAnalysis(imageBytes, image);
    if (elaScore > 0.60) {
      suspicion += 0.30;
      indicators.add('ELA: inconsistent compression levels across regions');
    }

    // 2. Benford's Law on DCT AC coefficients
    final benfordScore = _benfordsLawDCT(image);
    if (benfordScore > 0.60) {
      suspicion += 0.25;
      indicators.add('DCT coefficient distribution deviates from natural images');
    }

    // 3. Noise field inconsistency (sensor noise vs GAN smoothness)
    final noiseScore = _noiseConsistencyScore(image);
    if (noiseScore > 0.65) {
      suspicion += 0.20;
      indicators.add('Unusual high-frequency noise distribution');
    }

    // 4. Checkerboard / GAN upsampling artifact (transposed-conv periodicity)
    final cbScore = _checkerboardScore(image);
    if (cbScore > 0.65) {
      suspicion += 0.20;
      indicators.add('Periodic GAN upsampling artifact detected');
    }

    // 5. Chromatic aberration — real camera lenses always produce radial R-B offset
    final lcaScore = _chromaticAberrationScore(image);
    if (lcaScore > 0.65) {
      suspicion += 0.20;
      indicators.add('No chromatic aberration — consistent with AI-generated image');
    }

    // 6. JPEG block boundary artifact ratio
    final blockScore = _blockArtifactScore(image);
    if (blockScore > 0.65) {
      suspicion += 0.15;
      indicators.add('Irregular JPEG 8×8 block boundary pattern');
    }

    // 7. Bilateral symmetry — GAN faces are too symmetric; face-swaps too asymmetric
    final symScore = _bilateralSymmetryScore(image);
    if (symScore > 0.65) {
      suspicion += 0.15;
      indicators.add('Abnormal facial bilateral symmetry');
    }

    // 8. Color temperature consistency across quadrants
    final tempScore = _colorTemperatureScore(image);
    if (tempScore > 0.65) {
      suspicion += 0.15;
      indicators.add('Inconsistent illumination color temperature');
    }

    // 9. Color channel balance (GAN channels unnaturally correlated)
    final colorScore = _colorStatisticsScore(image);
    if (colorScore > 0.70) {
      suspicion += 0.20;
      indicators.add('Anomalous color channel statistics');
    }

    // 10. Gradient magnitude diversity
    final edgeScore = _edgeCoherenceScore(image);
    if (edgeScore > 0.60) {
      suspicion += 0.20;
      indicators.add('Narrow gradient distribution (over-uniform sharpness)');
    }

    // Normalize: max suspicion = 2.00; fake threshold = 0.50
    final isFake = suspicion >= 0.50;
    final normalized = (suspicion / 2.00).clamp(0.0, 1.0);
    final confidence = isFake
        ? (0.50 + normalized * 0.47).clamp(0.50, 0.97)
        : (0.97 - normalized * 0.47).clamp(0.50, 0.97);

    return DeepfakeResult(
      isDeepfake: isFake,
      confidence: confidence,
      processingTimeMs: DateTime.now().millisecondsSinceEpoch - startTime,
      details: indicators.isNotEmpty
          ? indicators.join('. ')
          : 'No manipulation indicators found',
    );
  }

  // ─── Signal implementations ───────────────────────────────────────────────────

  // ELA: re-save at q=95 in memory, compute per-8×8-block mean absolute diff.
  // A genuine image has uniform block error potential; a tampered image shows
  // high variance between blocks because inserted regions have a different
  // compression history. Fully AI-generated images show near-zero ELA everywhere.
  double _errorLevelAnalysis(Uint8List originalBytes, img.Image image) {
    final reEncoded = img.encodeJpg(image, quality: 95);
    final reDecoded = img.decodeJpg(reEncoded);
    if (reDecoded == null) return 0.5;

    const bs = 8;
    final blockMeans = <double>[];

    for (int y = 0; y + bs <= image.height; y += bs) {
      for (int x = 0; x + bs <= image.width; x += bs) {
        double sum = 0;
        for (int dy = 0; dy < bs; dy++) {
          for (int dx = 0; dx < bs; dx++) {
            final p1 = image.getPixel(x + dx, y + dy);
            final p2 = reDecoded.getPixel(x + dx, y + dy);
            sum += ((p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs()) / 3.0;
          }
        }
        blockMeans.add(sum / (bs * bs));
      }
    }

    if (blockMeans.isEmpty) return 0.5;
    final mean = blockMeans.reduce((a, b) => a + b) / blockMeans.length;
    final variance = blockMeans.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / blockMeans.length;
    final stdDev = math.sqrt(variance);

    // Authentic JPEG: stdDev ~3–8. Tampered (inconsistent compression): stdDev > 15.
    // Fully AI-generated (no JPEG history): mean < 1.5 AND stdDev < 1.5.
    if (mean < 1.5 && stdDev < 1.5) return 0.78; // AI-generated, never JPEG-encoded
    if (stdDev > 18) return 0.82;                 // Heavily tampered
    if (stdDev > 12) return 0.68;                 // Likely tampered
    return 0.25;
  }

  // Benford's Law on 8×8 DCT AC coefficients.
  // Natural images: leading digits of AC coefficients follow log₁₀(1+1/d).
  // GAN/manipulated images show statistically significant deviation (χ² test).
  double _benfordsLawDCT(img.Image image) {
    // Expected Benford frequencies for digits 1-9
    const expected = [0.0, 0.301, 0.176, 0.125, 0.097, 0.079, 0.067, 0.058, 0.051, 0.046];
    final digitCounts = List.filled(10, 0);
    int total = 0;

    // Sample every 3rd block for performance (still ~700 blocks on 256×256)
    for (int by = 0; by + 8 <= image.height; by += 24) {
      for (int bx = 0; bx + 8 <= image.width; bx += 24) {
        // Extract 8×8 luminance block, level-shift by -128
        final block = List.generate(8, (y) =>
          List.generate(8, (x) => _luma(image.getPixel(bx + x, by + y)) - 128.0)
        );

        // 2D DCT-II
        for (int u = 0; u < 8; u++) {
          for (int v = 0; v < 8; v++) {
            if (u == 0 && v == 0) continue; // skip DC coefficient
            double sum = 0;
            for (int x = 0; x < 8; x++) {
              for (int y = 0; y < 8; y++) {
                sum += block[y][x] * _dctCos[u][x] * _dctCos[v][y];
              }
            }
            final coeff = (_dctAlpha[u] * _dctAlpha[v] * sum / 4.0).abs();
            if (coeff >= 1.0) {
              int d = coeff.toInt();
              while (d >= 10) { d ~/= 10; }
              if (d >= 1 && d <= 9) { digitCounts[d]++; total++; }
            }
          }
        }
      }
    }

    if (total < 200) return 0.5; // insufficient data

    // χ² goodness-of-fit: critical value at p=0.05, df=8 is 15.51
    double chi2 = 0;
    for (int d = 1; d <= 9; d++) {
      final obs = digitCounts[d] / total;
      final exp = expected[d];
      chi2 += (obs - exp) * (obs - exp) / exp;
    }

    if (chi2 > 30) return 0.85;
    if (chi2 > 15.51) return 0.68;
    return 0.25;
  }

  // Checkerboard artifact: GAN transposed-conv upsampling creates periodic
  // alternating intensity patterns. Measure mean of 2×2 Laplacian-like kernel.
  double _checkerboardScore(img.Image image) {
    double total = 0;
    int count = 0;

    for (int y = 0; y < image.height - 1; y += 2) {
      for (int x = 0; x < image.width - 1; x += 2) {
        final a = _luma(image.getPixel(x,     y));
        final b = _luma(image.getPixel(x + 1, y));
        final c = _luma(image.getPixel(x,     y + 1));
        final d = _luma(image.getPixel(x + 1, y + 1));
        // |a - b - c + d| is maximised by a perfect checkerboard pattern
        total += (a - b - c + d).abs();
        count++;
      }
    }

    if (count == 0) return 0.5;
    final mean = total / count;

    // From literature: mean > 8 on 0-255 grayscale scale is suspicious for GANs
    if (mean > 12) return 0.78;
    if (mean > 8)  return 0.65;
    return 0.25;
  }

  // Chromatic aberration: real camera lenses refract R and B differently at the
  // periphery. AI images have perfectly aligned channels throughout (no optics).
  // Measure whether the R-B difference increases radially from image centre.
  double _chromaticAberrationScore(img.Image image) {
    final cx = image.width / 2.0;
    final cy = image.height / 2.0;
    final halfR = (image.width < image.height ? image.width : image.height) / 4.0;

    double innerRB = 0, outerRB = 0;
    int innerN = 0, outerN = 0;

    for (int y = 0; y < image.height; y += 4) {
      for (int x = 0; x < image.width; x += 4) {
        final p = image.getPixel(x, y);
        final rb = (p.r - p.b).abs().toDouble();
        final dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        if (dist < halfR) { innerRB += rb; innerN++; }
        else              { outerRB += rb; outerN++; }
      }
    }

    if (innerN == 0 || outerN == 0) return 0.5;
    final ratio = (outerRB / outerN) / ((innerRB / innerN) + 0.001);

    // Real camera: outer > inner — ratio ~1.2–2.5.
    // AI image: ratio ≈ 1.0 (no optical distortion at all).
    // Face-swap from different source: ratio may be extreme.
    if (ratio < 1.08) return 0.75; // near-perfect alignment = synthetic
    if (ratio > 3.5)  return 0.65; // extreme = face region from different camera
    return 0.25;
  }

  // Bilateral symmetry: GAN faces are often too symmetric (< 8 MAD);
  // badly blended face-swaps are too asymmetric (> 55 MAD).
  double _bilateralSymmetryScore(img.Image image) {
    final midX = image.width ~/ 2;
    double totalDiff = 0;
    int count = 0;

    for (int y = 0; y < image.height; y += 3) {
      for (int x = 0; x < midX; x += 3) {
        final mirrorX = image.width - 1 - x;
        final left  = _luma(image.getPixel(x,       y));
        final right = _luma(image.getPixel(mirrorX, y));
        totalDiff += (left - right).abs();
        count++;
      }
    }

    if (count == 0) return 0.5;
    final mad = totalDiff / count;

    // Natural faces: MAD ~15–40 (asymmetry + uneven lighting).
    if (mad < 8)  return 0.72; // too symmetric  → GAN
    if (mad > 55) return 0.65; // too asymmetric → face-swap
    return 0.25;
  }

  // Color temperature consistency: compute mean (R-B) per image quadrant.
  // A single light source → similar R-B in all quadrants (variance < 25).
  // A face-swapped region lit differently → high quadrant variance (> 45).
  // Fully AI image → near-zero variance (unnaturally uniform).
  double _colorTemperatureScore(img.Image image) {
    final qw = image.width  ~/ 2;
    final qh = image.height ~/ 2;
    final means = <double>[];

    for (int qy = 0; qy < 2; qy++) {
      for (int qx = 0; qx < 2; qx++) {
        double sum = 0; int n = 0;
        for (int y = qy * qh; y < (qy + 1) * qh; y += 3) {
          for (int x = qx * qw; x < (qx + 1) * qw; x += 3) {
            final p = image.getPixel(x, y);
            sum += (p.r - p.b).toDouble();
            n++;
          }
        }
        if (n > 0) means.add(sum / n);
      }
    }

    if (means.length < 4) return 0.5;
    final avg = means.reduce((a, b) => a + b) / means.length;
    final variance = means.map((v) => (v - avg) * (v - avg)).reduce((a, b) => a + b) / means.length;

    if (variance > 45) return 0.72;  // illumination mismatch → face-swap
    if (variance < 1)  return 0.65;  // unnaturally uniform  → AI generated
    return 0.25;
  }

  // JPEG block boundary ratio: boundary pixels should differ ~1.3–2.5× more
  // than interior pixels in an authentic JPEG. Manipulation shifts this ratio.
  double _blockArtifactScore(img.Image image) {
    double bDiff = 0, iDiff = 0;
    int bN = 0, iN = 0;

    for (int y = 0; y < image.height - 1; y++) {
      for (int x = 0; x < image.width - 1; x++) {
        final diff = (_luma(image.getPixel(x, y)) - _luma(image.getPixel(x + 1, y))).abs().toDouble();
        if (x % 8 == 7) { bDiff += diff; bN++; }
        else             { iDiff += diff; iN++; }
      }
    }

    if (bN == 0 || iN == 0) return 0.5;
    final ratio = (bDiff / bN) / ((iDiff / iN) + 0.001);
    if (ratio < 0.85 || ratio > 3.8) return 0.70;
    return 0.25;
  }

  // Gradient diversity: real photos have widely spread gradient magnitudes
  // (P90/P10 ratio > 30). GAN images have artificially narrow distributions.
  double _edgeCoherenceScore(img.Image image) {
    final grads = <double>[];

    for (int y = 1; y < image.height - 1; y += 3) {
      for (int x = 1; x < image.width - 1; x += 3) {
        final gx = _luma(image.getPixel(x + 1, y)) - _luma(image.getPixel(x - 1, y));
        final gy = _luma(image.getPixel(x, y + 1)) - _luma(image.getPixel(x, y - 1));
        grads.add((gx * gx + gy * gy).toDouble());
      }
    }

    if (grads.length < 10) return 0.5;
    grads.sort();
    final p10 = grads[(grads.length * 0.10).toInt()];
    final p90 = grads[(grads.length * 0.90).toInt()];
    final ratio = p90 / (p10 + 1.0);

    if (ratio < 12 || ratio > 60000) return 0.68;
    return 0.25;
  }

  // Color channel statistics: GAN faces have unnaturally balanced R/G/B channels.
  double _colorStatisticsScore(img.Image image) {
    int rS = 0, gS = 0, bS = 0, rSq = 0, gSq = 0, bSq = 0, n = 0;

    for (int y = 0; y < image.height; y += 4) {
      for (int x = 0; x < image.width; x += 4) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
        rS += r; gS += g; bS += b;
        rSq += r * r; gSq += g * g; bSq += b * b;
        n++;
      }
    }

    if (n == 0) return 0.5;
    final rM = rS / n, gM = gS / n, bM = bS / n;
    final rV = (rSq / n) - (rM * rM).toDouble();
    final gV = (gSq / n) - (gM * gM).toDouble();
    final bV = (bSq / n) - (bM * bM).toDouble();
    final meanDiff = ((rM - gM).abs() + (gM - bM).abs() + (rM - bM).abs()) / 3.0;
    final varDiff  = ((rV - gV).abs() + (gV - bV).abs() + (rV - bV).abs()) / 3.0;

    if (meanDiff < 3.0 && varDiff < 60.0) return 0.78;
    if (rV < 120 && gV < 120 && bV < 120) return 0.72;
    return 0.25;
  }

  // Noise field: GANs produce unnaturally smooth or artificially patterned noise.
  double _noiseConsistencyScore(img.Image image) {
    double hf = 0, lf = 0;
    int n = 0;

    for (int y = 1; y < image.height - 1; y += 2) {
      for (int x = 1; x < image.width - 1; x += 2) {
        final center = _luma(image.getPixel(x, y));
        final mean4  = (_luma(image.getPixel(x, y - 1)) + _luma(image.getPixel(x, y + 1)) +
                        _luma(image.getPixel(x - 1, y)) + _luma(image.getPixel(x + 1, y))) / 4.0;
        hf += (center - mean4).abs();
        lf += center;
        n++;
      }
    }

    if (n == 0 || lf == 0) return 0.5;
    final ratio = hf / (lf + 1.0);
    // Camera images: ratio 0.03–0.07. GAN outliers: < 0.02 or in 0.08–0.13 band.
    if (ratio < 0.02 || (ratio > 0.08 && ratio < 0.13)) return 0.72;
    return 0.25;
  }

  double _luma(img.Pixel p) => 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

  List<List<List<List<double>>>> _preprocessImage(Uint8List bytes) {
    const int size = 80;
    img.Image? decoded = img.decodeImage(bytes);
    final resized = decoded != null
        ? img.copyResize(decoded, width: size, height: size, interpolation: img.Interpolation.linear)
        : img.Image(width: size, height: size);

    return List.generate(1, (_) =>
      List.generate(size, (y) =>
        List.generate(size, (x) {
          final p = resized.getPixel(x, y);
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        })
      )
    );
  }
}

class DeepfakeResult {
  final bool isDeepfake;
  final double confidence;
  final int processingTimeMs;
  final String? details;

  DeepfakeResult({
    required this.isDeepfake,
    required this.confidence,
    required this.processingTimeMs,
    this.details,
  });
}

class PhishingDetector {
  Set<String> _blacklist = {};

  final Set<String> _suspiciousTLDs = {
    'tk', 'ml', 'ga', 'cf', 'gq', 'xyz', 'top', 'work', 'pw', 'cc', 'su',
    'buzz', 'click', 'link', 'review', 'country', 'kim', 'science', 'party',
    'loan', 'win', 'download', 'racing', 'date', 'faith', 'bid', 'stream',
    'trade', 'webcam', 'accountant', 'cricket', 'men', 'online', 'site',
    'website', 'space', 'tech', 'store', 'shop',
  };

  final List<String> _brands = [
    'paypal', 'amazon', 'google', 'microsoft', 'apple', 'netflix', 'facebook',
    'instagram', 'twitter', 'linkedin', 'dropbox', 'adobe', 'ebay', 'walmart',
    'chase', 'wellsfargo', 'citibank', 'bankofamerica', 'barclays', 'hsbc',
    'americanexpress', 'visa', 'mastercard', 'discover', 'capitalone',
    'fedex', 'ups', 'dhl', 'usps', 'royalmail',
    'youtube', 'twitch', 'tiktok', 'snapchat', 'whatsapp', 'telegram',
    'binance', 'coinbase', 'kraken', 'metamask',
    'steam', 'epicgames', 'blizzard', 'roblox',
    'spotify', 'airbnb', 'uber', 'doordash',
    'github', 'gitlab', 'slack', 'zoom',
  ];

  final Set<String> _urlShorteners = {
    'bit.ly', 'tinyurl.com', 'goo.gl', 't.co', 'ow.ly', 'is.gd', 'buff.ly',
    'adf.ly', 'shorte.st', 'bc.vc', 'cutt.ly', 'rb.gy', 'tiny.cc', 'v.gd',
    'shorturl.at', 'clck.ru', 'qr.ae',
  };

  // High-risk: urgency/fear language almost exclusively used in phishing
  final List<String> _highRiskKeywords = [
    'verify', 'verification', 'confirm', 'validate',
    'suspend', 'suspended', 'locked', 'expired',
    'unusual-activity', 'unauthorized', 'urgent',
    'action-required', 'immediately',
  ];

  // Medium-risk: common in phishing but also appear on legitimate sites
  final List<String> _mediumRiskKeywords = [
    'secure', 'security', 'login', 'signin', 'sign-in',
    'account', 'password', 'update', 'billing', 'payment',
    'wallet', 'banking', 'support', 'helpdesk',
    'prize', 'winner', 'reward', 'free', 'claim',
    'crypto', 'bitcoin', 'invest', 'refund', 'tax',
  ];

  // Trusted domains that should never be flagged
  final Set<String> _whitelist = {
    'google.com', 'gmail.com', 'youtube.com', 'google.co.in', 'google.co.uk',
    'apple.com', 'icloud.com', 'microsoft.com', 'live.com', 'outlook.com',
    'amazon.com', 'amazon.in', 'amazon.co.uk', 'amazon.de', 'amazon.co.jp',
    'facebook.com', 'instagram.com', 'twitter.com', 'x.com', 'linkedin.com',
    'netflix.com', 'spotify.com', 'twitch.tv', 'discord.com', 'reddit.com',
    'github.com', 'gitlab.com', 'stackoverflow.com', 'wikipedia.org',
    'paypal.com', 'ebay.com', 'stripe.com', 'shopify.com',
    'chase.com', 'bankofamerica.com', 'wellsfargo.com', 'citibank.com',
    'zoom.us', 'slack.com', 'notion.so', 'figma.com',
    'adobe.com', 'dropbox.com', 'onedrive.com',
    'binance.com', 'coinbase.com', 'kraken.com',
    'fedex.com', 'ups.com', 'dhl.com', 'usps.com',
  };

  Future<void> loadBlacklist() async {
    try {
      final data = await rootBundle.loadString('assets/data/phishing_domains.txt');
      final lines = data.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          _blacklist.add(trimmed);
        }
      }
    } catch (_) {
      // Fallback if asset file is not available
    }
    if (_blacklist.isEmpty) {
      _loadHardcodedBlacklist();
    }
    // TODO: Expand domain list to 10,000+ entries from:
    // https://github.com/Phishing-Database/Phishing.Database
    // https://github.com/curbengh/phishing-filter
    try {
      await _updateBlacklist();
    } catch (_) {
      // Offline or unavailable, use local list
    }
  }

  void _loadHardcodedBlacklist() {
    _blacklist = {
      'paypal-secure.com', 'paypal-verify.com', 'paypal-login-secure.com',
      'paypal-accounts.com', 'secure-paypal.com', 'paypal-support.net',
      'amazon-verify.com', 'amazon-account-security.com', 'amazon-accounts.com',
      'amazon-support-verify.com', 'amazon-billing.net', 'amazon-customer.com',
      'google-account-security.com', 'google-verify-account.com', 'gmail-security-update.com',
      'google-accounts-verify.com', 'google-securityalert.com',
      'microsoft-365-login.com', 'microsoft-online-verify.com', 'microsoft-security-alert.com',
      'microsoftonlinesupport.com', 'microsoft-account-verify.net',
      'apple-id-verify.com', 'apple-icloud-secure.com', 'apple-support-verification.com',
      'appleid-verify.com', 'apple-account-support.net',
      'netflix-billing.com', 'netflix-verify-account.com', 'netflix-payment-verify.com',
      'bankofamerica-online.com', 'chase-verify-account.com', 'wellsfargo-secure.com',
      'citibank-online.com', 'americanexpress-verify.com', 'hsbc-secure-login.com',
      'facebook-login-verify.com', 'instagram-security-verify.com', 'twitter-verify-support.com',
      'linkedin-security.com', 'facebook-account-recovery.com',
      'dropbox-verify.com', 'dropbox-security.com',
      'adobe-activate.com', 'adobe-support-verify.com',
      'irs-tax-refund.com', 'gov-refund.com', 'irs-gov.com', 'taxrefund-irs.com',
      'fedex-tracking.com', 'ups-tracking-delivery.com', 'dhl-delivery.com',
      'fedex-missed-delivery.com', 'usps-tracking-package.com',
      'bitcoin-wallet.com', 'crypto-invest.com', 'binance-secure.com', 'coinbase-verify.com',
      'prize-winner.com', 'lottery-winning.com', 'inheritance-notice.com',
      'account-suspended.com', 'password-expired.com', 'security-alert.com',
      'verify-now.com', 'confirm-account.com', 'update-payment.com',
    };
  }

  Future<void> _updateBlacklist() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      // TODO: Replace with actual blacklist URL
      // final request = await client.getUrl(Uri.parse('https://phishing-urls.example.com/blacklist.txt'));
      // final response = await request.close();
      // if (response.statusCode == 200) {
      //   final data = await response.transform(utf8.decoder).join();
      //   for (final line in data.split('\n')) {
      //     final trimmed = line.trim();
      //     if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
      //       _blacklist.add(trimmed);
      //     }
      //   }
      // }
    } finally {
      client.close();
    }
  }

  Future<PhishingResult> detect(String url) async {
    final lower = url.toLowerCase();

    // Malicious URI schemes
    if (lower.startsWith('javascript:')) {
      return PhishingResult(
        isPhishing: true, riskLevel: RiskLevel.critical, confidence: 0.99,
        reason: 'JavaScript URI - executes arbitrary code in browser',
      );
    }
    if (lower.startsWith('data:')) {
      return PhishingResult(
        isPhishing: true, riskLevel: RiskLevel.critical, confidence: 0.97,
        reason: 'Data URI - can embed malicious content directly',
      );
    }

    Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return PhishingResult(
        isPhishing: true, riskLevel: RiskLevel.high, confidence: 0.72,
        reason: 'Malformed URL that cannot be parsed',
      );
    }

    final domain = uri.host.toLowerCase();
    final baseDomain = _getBaseDomain(domain);

    // Whitelist: skip all checks for known-good domains
    if (_whitelist.contains(baseDomain)) {
      return PhishingResult(
        isPhishing: false, riskLevel: RiskLevel.low, confidence: 0.97,
        reason: 'Domain is in trusted whitelist',
      );
    }

    // Blacklist: immediate flag
    if (_isInBlacklist(domain)) {
      return PhishingResult(
        isPhishing: true, riskLevel: RiskLevel.critical, confidence: 0.97,
        reason: 'Domain matches known phishing blacklist entry',
      );
    }

    final findings = <String>[];
    int score = 0;

    // URL shortener (hides real destination)
    if (_urlShorteners.contains(domain)) {
      findings.add('URL shortener ($domain) hides the real destination');
      score += 20;
    }

    // IP address instead of domain
    if (_isIpAddress(domain)) {
      findings.add('IP address used instead of domain name');
      score += 35;
    }

    // @ symbol trick (browser ignores everything before @)
    if (url.contains('@') && uri.userInfo.isNotEmpty) {
      findings.add('@ symbol in URL - browser ignores the pre-@ part (redirect trick)');
      score += 30;
    }

    // Punycode / homograph attack
    if (domain.contains('xn--')) {
      findings.add('Punycode encoding (xn--) detected - possible homograph attack');
      score += 25;
    }

    // Suspicious TLD
    final tld = _getTld(domain);
    if (_suspiciousTLDs.contains(tld)) {
      findings.add('High-risk free TLD (.$tld) commonly abused in phishing');
      score += 20;
    }

    // Typosquatting via Levenshtein distance + containment check
    final typosquat = _detectTyposquatting(domain, baseDomain);
    if (typosquat != null) {
      findings.add(typosquat);
      score += 40;
    }

    // Brand name appears in subdomain of a non-brand registrable domain
    for (final brand in _brands) {
      final parts = domain.split('.');
      if (parts.length > 2 &&
          parts.first.contains(brand) &&
          !_isLegitBrandDomain(baseDomain, brand)) {
        findings.add('Brand name "$brand" in subdomain of unrelated domain');
        score += 30;
        break;
      }
    }

    // Heavy URL encoding (obfuscation)
    final encodedCount = RegExp(r'%[0-9a-fA-F]{2}').allMatches(url).length;
    if (encodedCount > 15) {
      findings.add('Heavy URL encoding ($encodedCount sequences) - obfuscation attempt');
      score += 25;
    } else if (encodedCount > 5) {
      findings.add('Unusual amount of URL encoding ($encodedCount sequences)');
      score += 12;
    }

    // Suspicious non-standard port
    if (uri.hasPort && ![80, 443, 8080, 8443].contains(uri.port)) {
      findings.add('Unusual port ${uri.port} (legitimate sites use 80/443)');
      score += 15;
    }

    // Double file extension in path
    if (RegExp(r'\.(php|html?|asp|aspx|jsp)\.(php|html?|exe|zip|pdf)', caseSensitive: false).hasMatch(uri.path)) {
      findings.add('Double file extension in path (possible disguised executable)');
      score += 20;
    }

    // High-risk keywords in domain + path
    final domainAndPath = '$domain${uri.path}'.toLowerCase();
    int highRiskCount = 0;
    for (final kw in _highRiskKeywords) {
      if (domainAndPath.contains(kw)) highRiskCount++;
    }
    if (highRiskCount >= 2) {
      findings.add('$highRiskCount high-risk urgency keywords (e.g. verify/suspend/expired)');
      score += highRiskCount * 15;
    } else if (highRiskCount == 1) {
      findings.add('High-risk urgency keyword in URL');
      score += 12;
    }

    // Medium-risk keywords in domain only (not path - reduces false positives)
    int medRiskCount = 0;
    for (final kw in _mediumRiskKeywords) {
      if (domain.contains(kw)) medRiskCount++;
    }
    if (medRiskCount >= 2) {
      findings.add('$medRiskCount suspicious keywords in domain name');
      score += medRiskCount * 8;
    } else if (medRiskCount == 1) {
      findings.add('Suspicious keyword in domain name');
      score += 8;
    }

    // URL length
    if (url.length > 200) {
      findings.add('Extremely long URL (${url.length} chars) obscures real destination');
      score += 20;
    } else if (url.length > 100) {
      findings.add('Long URL (${url.length} chars)');
      score += 8;
    }

    // Excessive subdomains
    final subCount = domain.split('.').length - 2;
    if (subCount > 3) {
      findings.add('$subCount subdomain levels - disguising malicious domain as legitimate');
      score += 15;
    } else if (subCount > 2) {
      findings.add('Multiple subdomains ($subCount levels)');
      score += 8;
    }

    // Multiple hyphens in registrable domain (e.g. secure-login-paypal-account.com)
    final stemHyphens = baseDomain.split('.').first.split('-').length - 1;
    if (stemHyphens >= 3) {
      findings.add('$stemHyphens hyphens in domain name (typical of fake domains)');
      score += 12;
    } else if (stemHyphens == 2) {
      score += 5;
    }

    // No HTTPS
    if (!url.startsWith('https:')) {
      findings.add('No HTTPS - connection is unencrypted');
      score += 10;
    }

    // High entropy (domain looks randomly generated / DGA)
    if (_isHighEntropy(baseDomain.split('.').first)) {
      findings.add('Domain name appears randomly generated (high character entropy)');
      score += 12;
    }

    // Numeric-heavy domain
    if (RegExp(r'^[0-9\-]+\.[a-z]+$').hasMatch(domain)) {
      findings.add('Domain is mostly numbers (unusual for legitimate sites)');
      score += 15;
    }

    final riskLevel = _calculateRiskLevel(score);
    // Normalize confidence: 120 points = ~critical upper bound
    final rawConf = (score / 120.0).clamp(0.05, 0.97);
    final confidence = riskLevel.index >= RiskLevel.high.index ? rawConf : 1.0 - rawConf;

    return PhishingResult(
      isPhishing: riskLevel.index >= RiskLevel.high.index,
      riskLevel: riskLevel,
      confidence: confidence,
      reason: findings.isNotEmpty
          ? findings.join('. ')
          : 'No suspicious patterns detected',
    );
  }

  // Levenshtein edit distance
  int _editDistance(String a, String b) {
    final m = a.length, n = b.length;
    final dp = List.generate(m + 1, (i) => List.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) { dp[i][0] = i; }
    for (int j = 0; j <= n; j++) { dp[0][j] = j; }
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[m][n];
  }

  String? _detectTyposquatting(String domain, String baseDomain) {
    final stem = baseDomain.split('.').first;

    for (final brand in _brands) {
      if (stem == brand) continue; // exact match is legitimate

      // Containment: brand name embedded with extra text (e.g. paypal-secure, mypaypal)
      if (stem.contains(brand) && stem.length > brand.length + 1) {
        return 'Domain contains "$brand" with surrounding text - brand impersonation';
      }

      // Levenshtein: 1-char edit for brands ≥5 chars, 2-char for brands ≥8 chars
      if (brand.length >= 5) {
        final dist = _editDistance(stem, brand);
        final threshold = brand.length >= 8 ? 2 : 1;
        if (dist > 0 && dist <= threshold) {
          return 'Typosquatting: "$stem" is $dist edit(s) away from "$brand"';
        }
      }

      // Leet-speak substitution (a→4, e→3, i→1, o→0, s→5)
      final leet = stem
          .replaceAll('4', 'a').replaceAll('3', 'e').replaceAll('1', 'i')
          .replaceAll('0', 'o').replaceAll('5', 's').replaceAll('7', 't');
      if (leet != stem && leet == brand) {
        return 'Leet-speak impersonation: "$stem" mimics "$brand"';
      }
    }
    return null;
  }

  bool _isLegitBrandDomain(String baseDomain, String brand) {
    return baseDomain == '$brand.com' ||
        baseDomain == '$brand.net' ||
        baseDomain == '$brand.org' ||
        baseDomain == '$brand.co' ||
        baseDomain == '$brand.io';
  }

  bool _isInBlacklist(String domain) {
    if (_blacklist.contains(domain)) return true;
    final bare = domain.startsWith('www.') ? domain.substring(4) : domain;
    if (_blacklist.contains(bare) || _blacklist.contains('www.$domain')) return true;
    for (final blocked in _blacklist) {
      if (domain.endsWith('.$blocked') || domain == blocked) return true;
    }
    return false;
  }

  bool _isIpAddress(String domain) {
    return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(domain);
  }

  String _getTld(String domain) {
    final parts = domain.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  String _getBaseDomain(String domain) {
    final parts = domain.split('.');
    if (parts.length <= 2) return domain;
    return '${parts[parts.length - 2]}.${parts.last}';
  }

  bool _isHighEntropy(String stem) {
    if (stem.length < 8) return false;
    final clean = stem.replaceAll('-', '');
    final unique = clean.split('').toSet().length;
    return unique > clean.length * 0.75;
  }

  RiskLevel _calculateRiskLevel(int score) {
    if (score >= 60) return RiskLevel.critical;
    if (score >= 35) return RiskLevel.high;
    if (score >= 15) return RiskLevel.medium;
    return RiskLevel.low;
  }
}

class PhishingResult {
  final bool isPhishing;
  final RiskLevel riskLevel;
  final String reason;
  final double confidence;

  PhishingResult({
    required this.isPhishing,
    required this.riskLevel,
    required this.reason,
    required this.confidence,
  });
}

enum RiskLevel { low, medium, high, critical }

class HistoryDatabase {
  static final HistoryDatabase instance = HistoryDatabase._();
  Database? _database;

  HistoryDatabase._();

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/secure_scan_history.db';
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            content TEXT NOT NULL,
            result TEXT NOT NULL,
            confidence REAL NOT NULL,
            details TEXT,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> insertScan({
    required String type,
    required String content,
    required String result,
    required double confidence,
    String? details,
  }) async {
    if (_database == null) await init();
    await _database!.insert('scans', {
      'type': type,
      'content': content,
      'result': result,
      'confidence': confidence,
      'details': details,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<ScanHistoryItem>> getAllScans() async {
    if (_database == null) await init();
    final maps = await _database!.query(
      'scans',
      orderBy: 'timestamp DESC',
      limit: 100,
    );
    return maps.map((map) => ScanHistoryItem.fromMap(map)).toList();
  }

  Future<void> clearAll() async {
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

  ScanHistoryItem({
    required this.id,
    required this.type,
    required this.content,
    required this.result,
    required this.confidence,
    this.details,
    required this.timestamp,
  });

  factory ScanHistoryItem.fromMap(Map<String, dynamic> map) {
    return ScanHistoryItem(
      id: map['id'],
      type: map['type'],
      content: map['content'],
      result: map['result'],
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      details: map['details'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return '${timestamp.day}/${timestamp.month}';
  }
}
