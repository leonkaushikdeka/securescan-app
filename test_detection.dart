import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/enhanced_phishing_detector.dart' as services;

class PhishingTestPage extends StatelessWidget {
  const PhishingTestPage({super.key});

  Future<void> _testDetection() async {
    final detector = services.EnhancedPhishingDetector();
    await detector.initialize();
    
    final testUrls = [
      'paypal-secure.com',
      'http://paypal-secure.com/login',
      'http://sbi-verify.com/account',
      'hdfc-login.net',
      'amazon-verify.com',
      'bit.ly/abc123',
      '192.168.1.1',
    ];
    
    print('\n🔍 PHISHING DETECTION TEST\n');
    print('=' * 50);
    
    for (final url in testUrls) {
      final result = await detector.detect(url);
      print('\nURL: $url');
      print('Domain: ${Uri.parse(url.startsWith('http') ? url : 'https://$url').host}');
      print('Risk: ${result.riskLevel.name.toUpperCase()} | Score: ${result.threatScore}');
      if (result.findings.isNotEmpty) {
        for (final f in result.findings.take(3)) {
          print('  - ${f.description}');
        }
      }
    }
    
    print('\n' + '=' * 50);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Phishing Detection')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _testDetection(),
              child: const Text('Run Detection Test'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: PhishingTestPage()));
}
