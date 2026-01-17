import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

enum RiskLevel { safe, low, medium, high, critical, unknown }

enum ThreatType {
  blacklist,
  ipAddress,
  redirect,
  urlShortener,
  suspiciousTLD,
  doubleExtension,
  typosquatting,
  suspiciousKeywords,
  urlLength,
  excessiveSubdomains,
  numericDomain,
  punycode,
  longPath,
  missingHTTPS,
  highEntropy,
  brandSubdomain,
  urgency,
  apkDownload,
  nonStandardPort,
  phishingPattern,
}

class ThreatFinding {
  final ThreatType type;
  final RiskLevel severity;
  final String description;
  final int score;

  const ThreatFinding({
    required this.type,
    required this.severity,
    required this.description,
    required this.score,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'severity': severity.name,
      'description': description,
      'score': score,
    };
  }
}

class PhishingDetectionResult {
  final String url;
  final bool isPhishing;
  final RiskLevel riskLevel;
  final int threatScore;
  final List<ThreatFinding> findings;
  final String reason;
  final Duration processingTime;

  const PhishingDetectionResult({
    required this.url,
    required this.isPhishing,
    required this.riskLevel,
    required this.threatScore,
    required this.findings,
    required this.reason,
    required this.processingTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'isPhishing': isPhishing,
      'riskLevel': riskLevel.name,
      'threatScore': threatScore,
      'findings': findings.map((f) => f.toMap()).toList(),
      'reason': reason,
      'processingTimeMs': processingTime.inMilliseconds,
    };
  }
}

class PhishingDetectorService {
  Set<String> _blacklist = {};
  final Set<String> _whitelist = {};

  final Map<String, List<String>> _indianBanks = {
    'Public Sector': ['sbi', 'onlinesbi', 'pnb', 'bankofbaroda', 'bobibanking', 'canarabank', 'unionbankofindia', 'indianbank', 'bankofmaharashtra', 'centralbank', 'indianoverseasbank', 'bankofindia'],
    'Private Sector': ['hdfcbank', 'hdfc', 'icicibank', 'icici', 'axisbank', 'axis', 'kotakbank', 'kotak', 'yesbank', 'indusindbank', 'indusind', 'idfcfirstbank', 'idfc', 'hsbc'],
    'Payment Apps': ['paytm', 'paytmbank', 'phonepe', 'googlepay', 'gpay', 'bhimupi', 'bhim', 'mobikwik', 'freecharge', 'amazonpay'],
    'Investment': ['zerodha', 'upstox', 'groww', 'angelone', '5paisa', 'icicidirect', 'hdfcsec', 'kotaksecurities'],
    'NBFCs': ['bajajfinserv', 'bajajfinance', 'tatafinance', 'tatacapital', 'chola', 'muthootfinance', 'muthoot', 'cred', 'slice', 'jupiter'],
  };

  final Map<String, List<String>> _indianGovernment = {
    'Central': ['uidai', 'aadhaar', 'incometax', 'incometaxindiaefiling', 'epfindia', 'nps', 'umang', 'digilocker', 'mygov', 'irctc', 'railway', 'passportindia', 'gst', 'gst.gov', 'mudra'],
    'States': ['ap', 'telangana', 'karnataka', 'maharashtra', 'delhi', 'kerala', 'tamilnadu', 'westbengal', 'gujarat', 'rajasthan'],
  };

  final Map<String, List<String>> _indianEcommerce = {
    'Marketplaces': ['flipkart', 'amazon.in', 'myntra', 'ajio', 'meesho', 'snapdeal', 'tatacliq', 'nykaa', 'bigbasket', 'jiomart', 'reliancedigital'],
    'Travel': ['makemytrip', 'mmt', 'goibibo', 'cleartrip', 'yatra', 'easemytrip', 'irctc', 'redbus', 'oyo'],
    'Food': ['swiggy', 'zomato', 'foodpanda'],
  };

  final List<String> _globalBrands = [
    'google', 'microsoft', 'apple', 'amazon', 'netflix', 'facebook', 'instagram', 'paypal', 'twitter', 'linkedin', 'adobe', 'dropbox', 'github', 'reddit',
  ];

  final List<String> _suspiciousTLDs = [
    'tk', 'ml', 'ga', 'cf', 'gq', 'xyz', 'top', 'work', 'pw', 'cc', 'su', 'buzz', 'click', 'link', 'review', 'country', 'kim', 'science', 'party', 'zip', 'mov', 'online', 'site', 'space',
  ];

  final List<String> _suspiciousKeywords = [
    'secure', 'account', 'login', 'update', 'confirm', 'verify', 'wallet', 'banking', 'password', 'support', 'official', 'document', 'tax', 'refund', 'prize', 'winner', 'lottery',
    'inheritance', 'bitcoin', 'crypto', 'mining', 'invest', 'urgent', 'immediate', 'action', 'required', 'suspended', 'locked', 'verifynow', 'securelogin',
    'kyc', 'aadhaar', 'pan', 'sebi', 'rbi', 'epfo', 'uan', 'cashback', 'recharge', 'bill', 'disconnection', 'courier', 'parcel', 'customs', 'delivery', 'tracking', 'otp', 'mpin', 'cvv',
  ];

  final List<String> _urlShorteners = [
    'bit.ly', 'tinyurl.com', 'goo.gl', 't.co', 'is.gd', 'buff.ly', 'adf.ly', 'ow.ly', 'tr.im', 'short.to', 'budurl.com', 'ping.fm', 'post.ly', 'just.as', 'snipr.com', 'loopt.us', 'doiop.com', 'short.ie', 'kl.am', 'wp.me', 'rubyurl.com', 'lnkd.in', 'db.tt', 'qr.ae', 'cur.lv', 'ity.im', 'po.st', 'bc.vc', 'v.gd', 'rb.gy', 'shorturl.at', 'cutt.ly',
  ];

  final List<String> _legitimateDomains = [
    'google.com', 'google.co.in', 'gmail.com', 'youtube.com', 'microsoft.com', 'microsoftonline.com', 'office.com', 'apple.com', 'icloud.com', 'amazon.com', 'amazon.in',
    'facebook.com', 'instagram.com', 'whatsapp.com', 'netflix.com', 'paypal.com', 'paypal.in', 'github.com', 'wikipedia.org',
    'sbi.co.in', 'onlinesbi.com', 'hdfcbank.com', 'icicibank.com', 'axisbank.com', 'kotak.com', 'yesbank.in',
    'paytm.com', 'phonepe.com', 'bhimupi.org', 'gpay.com', 'mobikwik.com', 'freecharge.in',
    'uidai.gov.in', 'aadhaar.gov.in', 'incometax.gov.in', 'epfindia.gov.in', 'irctc.co.in', 'passportindia.gov.in', 'digilocker.gov.in',
    'flipkart.com', 'myntra.com', 'ajio.com', 'jiomart.com', 'reliancedigital.com', 'makemytrip.com', 'goibibo.com',
    'zerodha.com', 'upstox.com', 'groww.in', 'angelone.in',
  ];

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _whitelist.addAll(_legitimateDomains);
    await _loadBlacklist();
    _isInitialized = true;
  }

  Future<void> _loadBlacklist() async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final manifest = json.decode(manifestJson) as Map<String, dynamic>;
      final keys = manifest.keys.where((k) => k.contains('phishing') && k.endsWith('.txt'));

      if (keys.isNotEmpty) {
        final content = await rootBundle.loadString(keys.first);
        final lines = content.split('\n');
        for (final line in lines) {
          final trimmed = line.trim().toLowerCase();
          if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
            _blacklist.add(trimmed);
          }
        }
      }

      _addBuiltInBlacklist();
    } catch (e) {
      _addBuiltInBlacklist();
    }
  }

  void _addBuiltInBlacklist() {
    _blacklist.addAll([
      'paypal-secure.com', 'paypal-verify.com', 'paypal-login-secure.com', 'amazon-verify.com', 'amazon-account-security.com',
      'google-account-security.com', 'google-verify-account.com', 'gmail-security-update.com', 'microsoft-365-login.com',
      'apple-id-verify.com', 'apple-icloud-secure.com', 'netflix-billing.com', 'facebook-login-verify.com',
      'sbi-secure.com', 'sbi-verify.com', 'hdfc-secure.com', 'hdfc-verify.com', 'hdfc-login.net', 'icici-secure.com',
      'axis-secure.com', 'kotak-secure.com', 'paytm-secure.com', 'paytm-verify.com', 'phonepe-secure.com',
      'uidai-secure.com', 'aadhaar-verify.com', 'epf-secure.com', 'irs-tax-refund.com',
      'account-suspended.com', 'password-expired.com', 'security-alert.com', 'verify-now.com',
    ]);
  }

  Future<PhishingDetectionResult> detect(String url) async {
    final stopwatch = Stopwatch()..start();

    if (!_isInitialized) await initialize();

    final findings = <ThreatFinding>[];
    int threatScore = 0;

    try {
      final processedUrl = _normalizeUrl(url);
      final uri = Uri.parse(processedUrl);
      final domain = uri.host.toLowerCase();
      final fullUrl = processedUrl.toLowerCase();

      // Check whitelist first
      if (_isWhitelisted(domain)) {
        stopwatch.stop();
        return PhishingDetectionResult(
          url: processedUrl,
          isPhishing: false,
          riskLevel: RiskLevel.safe,
          threatScore: 0,
          findings: [],
          reason: 'This is a known legitimate domain',
          processingTime: stopwatch.elapsed,
        );
      }

      // 1. Blacklist check
      if (_isInBlacklist(domain)) {
        findings.add(const ThreatFinding(type: ThreatType.blacklist, severity: RiskLevel.critical, description: 'Domain found in known phishing blacklist', score: 60));
        threatScore += 60;
      }

      // 2. IP address check
      if (_isIpAddress(domain)) {
        findings.add(const ThreatFinding(type: ThreatType.ipAddress, severity: RiskLevel.critical, description: 'URL uses IP address instead of domain name', score: 35));
        threatScore += 35;
      }

      // 3. @ symbol redirect attack
      if (fullUrl.contains('@')) {
        findings.add(const ThreatFinding(type: ThreatType.redirect, severity: RiskLevel.critical, description: 'URL contains @ symbol (possible redirect attack)', score: 35));
        threatScore += 35;
      }

      // 4. URL shortener
      final shortener = _detectUrlShortener(domain);
      if (shortener != null) {
        findings.add(ThreatFinding(type: ThreatType.urlShortener, severity: RiskLevel.high, description: 'URL shortener detected ($shortener)', score: 20));
        threatScore += 20;
      }

      // 5. Suspicious TLD
      final tld = _getTld(domain);
      if (_suspiciousTLDs.contains(tld)) {
        findings.add(ThreatFinding(type: ThreatType.suspiciousTLD, severity: RiskLevel.high, description: 'Suspicious TLD (.${tld}) often used in phishing', score: 20));
        threatScore += 20;
      }

      // 6. Double extensions
      if (RegExp(r'\.(php|html?|asp|jsp|aspx)\.(php|html?|asp|jsp|aspx)$', caseSensitive: false).hasMatch(fullUrl)) {
        findings.add(const ThreatFinding(type: ThreatType.doubleExtension, severity: RiskLevel.high, description: 'Suspicious double file extension detected', score: 15));
        threatScore += 15;
      }

      // 7. Indian bank typosquatting
      final bankTyposquat = _detectTyposquatting(domain, _indianBanks);
      if (bankTyposquat != null) {
        findings.add(ThreatFinding(type: ThreatType.typosquatting, severity: RiskLevel.critical, description: 'Possible bank impersonation: $bankTyposquat', score: 40));
        threatScore += 40;
      }

      // 8. Payment app typosquatting
      final paymentTyposquat = _detectPaymentAppTyposquatting(domain);
      if (paymentTyposquat != null) {
        findings.add(ThreatFinding(type: ThreatType.typosquatting, severity: RiskLevel.critical, description: 'Possible payment app impersonation: $paymentTyposquat', score: 40));
        threatScore += 40;
      }

      // 9. Government impersonation
      final govTyposquat = _detectTyposquatting(domain, _indianGovernment);
      if (govTyposquat != null) {
        findings.add(ThreatFinding(type: ThreatType.typosquatting, severity: RiskLevel.critical, description: 'Possible government impersonation: $govTyposquat', score: 40));
        threatScore += 40;
      }

      // 10. Global brand typosquatting
      final brandTyposquat = _detectGlobalBrandTyposquatting(domain);
      if (brandTyposquat != null) {
        findings.add(ThreatFinding(type: ThreatType.typosquatting, severity: RiskLevel.high, description: 'Possible typosquatting: $brandTyposquat', score: 35));
        threatScore += 35;
      }

      // 11. Suspicious keywords
      final keywordCount = _countSuspiciousKeywords(domain);
      if (keywordCount >= 2) {
        findings.add(ThreatFinding(type: ThreatType.suspiciousKeywords, severity: RiskLevel.medium, description: 'Multiple suspicious keywords ($keywordCount)', score: keywordCount * 8));
        threatScore += keywordCount * 8;
      } else if (keywordCount == 1) {
        findings.add(const ThreatFinding(type: ThreatType.suspiciousKeywords, severity: RiskLevel.low, description: 'Suspicious keyword found', score: 8));
        threatScore += 8;
      }

      // 12. Excessive subdomains
      final subdomainCount = domain.split('.').length - 2;
      if (subdomainCount > 3) {
        findings.add(ThreatFinding(type: ThreatType.excessiveSubdomains, severity: RiskLevel.low, description: 'Excessive subdomains ($subdomainCount)', score: 5));
        threatScore += 5;
      }

      // 13. Numeric domain
      if (RegExp(r'^[0-9.-]+\.[a-z]+$').hasMatch(domain)) {
        findings.add(const ThreatFinding(type: ThreatType.numericDomain, severity: RiskLevel.medium, description: 'Domain contains mostly numbers', score: 10));
        threatScore += 10;
      }

      // 14. Punycode/homograph attack
      if (domain.contains('xn--')) {
        findings.add(const ThreatFinding(type: ThreatType.punycode, severity: RiskLevel.high, description: 'Punycode detected - possible homograph attack', score: 25));
        threatScore += 25;
      }

      // 15. Missing HTTPS
      if (!fullUrl.startsWith('https:')) {
        findings.add(const ThreatFinding(type: ThreatType.missingHTTPS, severity: RiskLevel.low, description: 'URL does not use HTTPS', score: 8));
        threatScore += 8;
      }

      // 16. Brand in subdomain
      if (_hasBrandInSubdomain(domain)) {
        findings.add(const ThreatFinding(type: ThreatType.brandSubdomain, severity: RiskLevel.high, description: 'Brand name in subdomain', score: 25));
        threatScore += 25;
      }

      // 17. APK download
      if (fullUrl.endsWith('.apk') || fullUrl.contains('.apk?')) {
        findings.add(const ThreatFinding(type: ThreatType.apkDownload, severity: RiskLevel.critical, description: 'APK download link detected', score: 40));
        threatScore += 40;
      }

      // 18. Non-standard port
      if (uri.port != 0 && uri.port != 80 && uri.port != 443) {
        findings.add(ThreatFinding(type: ThreatType.nonStandardPort, severity: RiskLevel.medium, description: 'Non-standard port (${uri.port})', score: 15));
        threatScore += 15;
      }

      // 19. Urgency language
      if (_hasUrgencyLanguage(fullUrl)) {
        findings.add(const ThreatFinding(type: ThreatType.urgency, severity: RiskLevel.high, description: 'Urgent language typical of phishing', score: 20));
        threatScore += 20;
      }

      // 20. Prize/lottery scam
      if (_hasPrizeScamLanguage(fullUrl)) {
        findings.add(const ThreatFinding(type: ThreatType.phishingPattern, severity: RiskLevel.high, description: 'Prize/lottery scam language', score: 25));
        threatScore += 25;
      }

      // 21. Delivery scam
      if (_hasDeliveryScamLanguage(fullUrl)) {
        findings.add(const ThreatFinding(type: ThreatType.phishingPattern, severity: RiskLevel.high, description: 'Parcel/courier scam language', score: 20));
        threatScore += 20;
      }

      // 22. Levenshtein distance detection
      final levenshteinTyposquat = _detectLevenshteinTyposquatting(domain);
      if (levenshteinTyposquat != null) {
        findings.add(ThreatFinding(type: ThreatType.typosquatting, severity: RiskLevel.high, description: 'Possible typosquatting: $levenshteinTyposquat', score: 35));
        threatScore += 35;
      }

      stopwatch.stop();

      final riskLevel = _calculateRiskLevel(threatScore);
      final isPhishing = riskLevel.index >= RiskLevel.high.index;

      return PhishingDetectionResult(
        url: processedUrl,
        isPhishing: isPhishing,
        riskLevel: riskLevel,
        threatScore: threatScore,
        findings: findings,
        reason: findings.isNotEmpty ? findings.map((f) => f.description).join('. ') : 'No suspicious patterns detected',
        processingTime: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      return PhishingDetectionResult(
        url: url,
        isPhishing: false,
        riskLevel: RiskLevel.unknown,
        threatScore: 0,
        findings: [],
        reason: 'Error analyzing URL: ${e.toString()}',
        processingTime: stopwatch.elapsed,
      );
    }
  }

  // Helper methods
  String _normalizeUrl(String url) => url.startsWith('http') ? url : 'https://$url';

  bool _isWhitelisted(String domain) {
    if (_whitelist.contains(domain)) return true;
    if (domain.startsWith('www.') && _whitelist.contains(domain.substring(4))) return true;
    return false;
  }

  bool _isInBlacklist(String domain) {
    if (_blacklist.contains(domain)) return true;
    if (domain.startsWith('www.') && _blacklist.contains(domain.substring(4))) return true;
    for (final blocked in _blacklist) {
      if (domain.contains(blocked) || blocked.contains(domain)) return true;
    }
    return false;
  }

  bool _isIpAddress(String domain) => RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(domain);

  String? _detectUrlShortener(String domain) {
    for (final shortener in _urlShorteners) {
      if (domain.contains(shortener)) return shortener;
    }
    return null;
  }

  String _getTld(String domain) {
    final parts = domain.split('.');
    return parts.isNotEmpty ? parts.last : '';
  }

  String? _detectTyposquatting(String domain, Map<String, List<String>> entities) {
    for (final category in entities.values) {
      for (final brand in category) {
        if (domain.contains(brand)) {
          final officialDomains = ['$brand.com', '$brand.in', '$brand.co.in', '$brand.gov.in', '$brand.org'];
          if (officialDomains.any((d) => domain == d)) continue;

          final typos = _generateTypos(brand);
          for (final typo in typos) {
            if (domain.contains(typo)) return '"$typo" looks like "$brand"';
          }
          return '"$domain" contains "$brand" but is not official';
        }
      }
    }
    return null;
  }

  String? _detectPaymentAppTyposquatting(String domain) {
    final paymentApps = ['paytm', 'phonepe', 'googlepay', 'gpay', 'bhim', 'mobikwik', 'freecharge'];
    for (final app in paymentApps) {
      if (domain.contains(app)) {
        if (domain == '$app.com' || domain == '$app.in' || domain == 'paytm.com') continue;
        final typos = _generateTypos(app);
        for (final typo in typos) {
          if (domain.contains(typo)) return '"$typo" looks like "$app"';
        }
        return '"$domain" contains "$app" but is not official';
      }
    }
    return null;
  }

  String? _detectGlobalBrandTyposquatting(String domain) {
    for (final brand in _globalBrands) {
      if (domain.contains(brand)) {
        if (domain == '$brand.com') continue;
        final typos = _generateTypos(brand);
        for (final typo in typos) {
          if (domain.contains(typo)) return '"$typo" looks like "$brand"';
        }
        return '"$domain" contains "$brand" but is not official';
      }
    }
    return null;
  }

  List<String> _generateTypos(String brand) {
    final typos = <String>[];
    final subs = {'a': '4', 'e': '3', 'i': '1', 'o': '0', 's': '5'};
    for (final entry in subs.entries) {
      typos.add(brand.replaceAll(entry.key, entry.value));
    }
    for (int i = 1; i <= 5; i++) {
      typos.add('$brand$i');
      typos.add('$i$brand');
    }
    final keywords = ['secure', 'login', 'verify', 'update', 'support', 'account', 'alert', 'confirm'];
    for (final kw in keywords) {
      typos.add('$brand-$kw');
      typos.add('secure-$brand');
      typos.add('login-$brand');
    }
    return typos;
  }

  int _countSuspiciousKeywords(String domain) {
    int count = 0;
    for (final keyword in _suspiciousKeywords) {
      if (domain.contains(keyword)) count++;
    }
    return count;
  }

  bool _hasBrandInSubdomain(String domain) {
    final parts = domain.split('.');
    if (parts.length < 3) return false;
    final subdomain = parts[0].toLowerCase();
    final mainDomain = parts[1].toLowerCase();
    final allBrands = [..._indianBanks.values.expand((e) => e), ..._globalBrands];
    for (final brand in allBrands) {
      if (brand.length >= 4 && subdomain.contains(brand.toLowerCase()) && mainDomain != brand.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  bool _hasUrgencyLanguage(String url) {
    final patterns = ['urgent', 'immediately', 'act now', 'within 24 hours', 'account suspended', 'account blocked', 'kyc pending', 'verify now', 'final notice', 'last warning', 'click here'];
    final lower = url.toLowerCase();
    return patterns.any((p) => lower.contains(p));
  }

  bool _hasPrizeScamLanguage(String url) {
    final patterns = ["you've won", 'congratulations', 'winner', 'selected for', 'lottery', 'prize', 'cashback', '₹', 'rs ', 'free iphone', 'free samsung'];
    final lower = url.toLowerCase();
    return patterns.any((p) => lower.contains(p));
  }

  bool _hasDeliveryScamLanguage(String url) {
    final patterns = ['parcel', 'courier', 'package', 'shipment', 'detained', 'customs', 'clearance', 'delivery charge', 'package pending'];
    final lower = url.toLowerCase();
    return patterns.any((p) => lower.contains(p));
  }

  int _levenshteinDistance(String a, String b) {
    if (a.length > b.length) return _levenshteinDistance(b, a);
    if (a.isEmpty) return b.length;
    final row = List.generate(b.length + 1, (i) => i);
    for (int i = 0; i < a.length; i++) {
      int prev = i + 1;
      for (int j = 0; j < b.length; j++) {
        final current = a[i] == b[j] ? row[j] : row[j] + 1;
        row[j] = prev;
        prev = current > row[j] ? row[j] : current;
      }
      row[b.length] = prev;
    }
    return row[b.length];
  }

  String? _detectLevenshteinTyposquatting(String domain) {
    final brands = [..._indianBanks.values.expand((e) => e), 'paytm', 'phonepe', 'googlepay', 'gpay', 'bhim', ..._globalBrands];
    final cleanDomain = domain.split('.').first;
    for (final brand in brands) {
      if (brand.length < 4) continue;
      final distance = _levenshteinDistance(cleanDomain, brand);
      final maxDistance = (brand.length * 0.3).floor() + 1;
      if (distance > 0 && distance <= maxDistance) {
        return '"$domain" is $distance edit(s) from "$brand"';
      }
    }
    return null;
  }

  RiskLevel _calculateRiskLevel(int score) {
    if (score >= 80) return RiskLevel.critical;
    if (score >= 50) return RiskLevel.high;
    if (score >= 25) return RiskLevel.medium;
    if (score >= 10) return RiskLevel.low;
    return RiskLevel.safe;
  }
}
