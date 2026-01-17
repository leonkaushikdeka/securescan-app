import 'package:test/test.dart';
import 'package:securescanapp_new/lib/features/phishing/phishing_detector_service.dart';

void main() {
  late PhishingDetectorService detector;

  setUp(() async {
    detector = PhishingDetectorService();
    await detector.initialize();
  });

  group('Phishing Detection', () {
    test('should detect legitimate domains', () async {
      final result = await detector.detect('google.com');
      expect(result.riskLevel, RiskLevel.safe);
      expect(result.isPhishing, false);
    });

    test('should detect Indian bank domains', () async {
      final result = await detector.detect('sbi.co.in');
      expect(result.riskLevel, RiskLevel.safe);
    });

    test('should flag known phishing domains', () async {
      final result = await detector.detect('paypal-secure.com');
      expect(result.isPhishing, true);
      expect(result.riskLevel, RiskLevel.critical);
    });

    test('should detect IP addresses', () async {
      final result = await detector.detect('http://192.168.1.1/login');
      expect(result.isPhishing, true);
      expect(result.findings.any((f) => f.type == ThreatType.ipAddress), true);
    });

    test('should detect @ symbol redirect', () async {
      final result = await detector.detect('http://paypal.com@malicious.com');
      expect(result.isPhishing, true);
      expect(result.findings.any((f) => f.type == ThreatType.redirect), true);
    });

    test('should detect URL shorteners', () async {
      final result = await detector.detect('bit.ly/abc123');
      expect(result.findings.any((f) => f.type == ThreatType.urlShortener), true);
    });

    test('should detect suspicious TLDs', () async {
      final result = await detector.detect('paypal-verify.xyz');
      expect(result.findings.any((f) => f.type == ThreatType.suspiciousTLD), true);
    });

    test('should detect typosquatting', () async {
      final result = await detector.detect('goole.com');
      expect(result.findings.any((f) => f.type == ThreatType.typosquatting), true);
    });

    test('should detect urgency language', () async {
      final result = await detector.detect('urgent-account-suspended.com');
      expect(result.findings.any((f) => f.type == ThreatType.urgency), true);
    });
  });
}

enum RiskLevel { safe, low, medium, high, critical, unknown }
enum ThreatType { blacklist, ipAddress, redirect, urlShortener, suspiciousTLD, typosquatting, urgency }
