import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

class EnhancedPhishingDetector {
  Set<String> _blacklist = {};
  Set<String> _whitelist = {};

  // Known legitimate domains (ALWAYS SAFE)
  final List<String> _knownLegitimateDomains = [
    // Global Tech
    'google.com', 'google.co.in', 'gmail.com', 'youtube.com',
    'microsoft.com', 'microsoftonline.com', 'office.com', 'windows.com',
    'apple.com', 'icloud.com', 'appleid.apple.com',
    'amazon.com', 'amazon.in', 'aws.amazon.com',
    'facebook.com', 'instagram.com', 'whatsapp.com', 'meta.com',
    'twitter.com', 'x.com', 'linkedin.com', 'netflix.com',
    'paypal.com', 'paypal.in',
    'github.com', 'gitlab.com', 'stackoverflow.com',
    'wikipedia.org', 'reddit.com',

    // Indian Banks - Public Sector
    'sbi.co.in', 'onlinesbi.com', 'bankofbaroda.in', 'bobibanking.com',
    'canarabank.com', 'unionbankofindia.co.in', 'centralbankofindia.co.in',
    'bankofindia.co.in', 'pnbindia.in', 'indianbank.in',

    // Indian Banks - Private Sector
    'hdfcbank.com', 'icicibank.com', 'axisbank.com', 'kotak.com',
    'yesbank.in', 'indusind.com', 'idfcfirstbank.com', 'hsbc.co.in',

    // Indian Payment Apps
    'paytm.com', 'paytmbank.com', 'phonepe.com', 'bhimupi.org',
    'gpay.com', 'googlepay.com', 'mobikwik.com', 'freecharge.in',

    // Indian Government
    'uidai.gov.in', 'aadhaar.gov.in', 'incometax.gov.in',
    'incometaxindiaefiling.gov.in', 'epfindia.gov.in',
    'irctc.co.in', 'irctc.com', 'railway.gov.in',
    'passportindia.gov.in', 'digilocker.gov.in',
    'umang.gov.in', 'mygov.in', 'gst.gov.in', 'gstin.gov.in',

    // Indian E-commerce & Services
    'flipkart.com', 'myntra.com', 'ajio.com', 'amazon.in',
    'jiomart.com', 'reliancejio.com', 'airtel.in', 'jio.com',
    'makemytrip.com', 'goibibo.com', 'cleartrip.com',

    // Investment
    'zerodha.com', 'upstox.com', 'groww.in', 'angelone.in',
  ];

  // INDIAN BANKING & FINANCIAL INSTITUTIONS
  final Map<String, List<String>> _indianBanks = {
    'Public Sector Banks': [
      'sbi', 'onlinesbi', 'pnb', 'bankofbaroda', 'bobibanking', 'canarabank',
      'unionbankofindia', 'indianbank', 'bankofmaharashtra', 'centralbank',
      'indianoverseasbank', 'ucbank', 'bankofindia', 'syndicatebank',
      'andhrabank', 'coromandelbank', 'corporationbank', 'vijayabank',
      'denabank', 'ideabank', 'punjabandsindbank',
    ],
    'Private Sector Banks': [
      'hdfcbank', 'hdfc', 'icicibank', 'icici', 'axisbank', 'axis',
      'kotakbank', 'kotak', 'yesbank', 'indusindbank', 'indusind',
      'idfcfirstbank', 'idfc', 'rblbank', 'bandhanbank',
      'federalbank', 'southindianbank', 'karurbank', 'cityunionbank',
      'dcbbank', 'aubank', 'citybank', 'hsbc', 'sc', 'standardchartered',
    ],
    'Payment Banks & Wallets': [
      'paytm', 'paytmbank', 'phonepe', 'googlepay', 'gpay', 'bhimupi', 'bhim',
      'mobikwik', 'freecharge', 'amazonpay', 'airtelmoney', 'airtelbank',
      'jiomoney', 'olamoney', 'jiope', 'airtelpaymentsbank',
    ],
    'Investment & Trading': [
      'zerodha', 'kite', 'coin', 'upstox', 'groww', 'angelone', 'angelbroking',
      '5paisa', 'icicidirect', 'hdfcsec', 'motilaloswalsec', 'sharekhan',
      'kotaksecurities', 'edelweiss', 'geojit', 'samco',
    ],
    'NBFCs & Fintech': [
      'bajajfinserv', 'bajajfinance', 'hdbfinancial', 'hdb',
      'tatafinance', 'tatacapital', 'chola', 'cholamandalam',
      'muthootfinance', 'muthoot', 'manappuram', 'cred',
      'slice', 'jupiter', 'fi', 'fimoney', 'niyo', 'cashe',
    ],
  };

  // Global brands for typosquatting detection
  final List<String> _globalBrands = [
    'google', 'microsoft', 'apple', 'amazon', 'netflix', 'facebook',
    'instagram', 'paypal', 'twitter', 'linkedin', 'adobe', 'dropbox',
    'github', 'gitlab', 'stackoverflow', 'reddit', 'wikipedia',
  ];

  // Suspicious TLDs
  final List<String> _suspiciousTLDs = [
    'tk', 'ml', 'ga', 'cf', 'gq', 'xyz', 'top', 'work', 'pw', 'cc', 'su', 'buzz',
    'click', 'link', 'review', 'country', 'kim', 'science', 'party', 'zip', 'mov',
    'online', 'site', 'space', 'webcam', 'download', 'stream', 'racing', 'winner',
    'trust', 'accountant', 'bid', 'date', 'faith', 'loan', 'men', 'win', 'game',
    'gaming', 'hosting', 'info', 'network', 'pro', 'store', 'tech', 'video',
    'website', 'wiki', 'zone', 'fit', 'club', 'agency', 'today',
  ];

  // Suspicious keywords in domain
  final List<String> _suspiciousKeywords = [
    'secure', 'account', 'login', 'update', 'confirm', 'verify', 'wallet',
    'banking', 'password', 'support', 'service', 'customer', 'help',
    'official', 'document', 'irs', 'tax', 'refund', 'prize', 'winner',
    'lottery', 'inheritance', 'bitcoin', 'crypto', 'mining', 'invest',
    'limited', 'urgent', 'immediate', 'action', 'required', 'suspended',
    'locked', 'unusual', 'verifynow', 'securelogin', 'accountupdate',
    'paymentverify', 'billingconfirm', 'identitycheck', 'securityalert',
    'fbrecover', 'gmailverify', 'paypalconfirm', 'appleidverify',
    'microsoftaccount', 'netflixbilling',
    // Indian specific
    'kyc', 'aadhaar', 'pan', 'sebi', 'rbi', 'epfo', 'uan',
    'cashback', 'recharge', 'bill', 'disconnection', 'pending',
    'courier', 'parcel', 'customs', 'delivery', 'tracking',
    'otp', 'mpin', 'upi', 'cvv', 'atm pin',
  ];

  // URL shorteners
  final List<String> _urlShorteners = [
    'bit.ly', 'tinyurl.com', 'goo.gl', 't.co', 'is.gd', 'buff.ly',
    'adf.ly', 'j.mp', 'ow.ly', 'tr.im', 'cli.gs', 'short.to',
    'budurl.com', 'ping.fm', 'post.ly', 'just.as', 'bkite.com',
    'snipr.com', 'fic.kr', 'loopt.us', 'doiop.com', 'short.ie',
    'kl.am', 'wp.me', 'rubyurl.com', 'om.ly', 'to.ly', 'bit.do',
    'lnkd.in', 'db.tt', 'qr.ae', 'cur.lv', 'ity.im', 'q.gs',
    'po.st', 'bc.vc', 'twitthis.com', 'u.telecom', 'yourls.org',
    'v.gd', 'rb.gy', 'shorturl.at', 'cutt.ly', 'shorte.st',
  ];

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadBlacklist();
    _whitelist = _knownLegitimateDomains.toSet();
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
      // Banking phishing
      'paypal-secure.com', 'paypal-verify.com', 'paypal-login-secure.com',
      'amazon-verify.com', 'amazon-account-security.com', 'amazon-accounts.com',
      'google-account-security.com', 'google-verify-account.com', 'gmail-security-update.com',
      'microsoft-365-login.com', 'microsoft-online-verify.com', 'microsoft-security-alert.com',
      'apple-id-verify.com', 'apple-icloud-secure.com', 'apple-support-verification.com',
      'netflix-billing.com', 'netflix-verify-account.com', 'netflix-payment-verify.com',
      'facebook-login-verify.com', 'instagram-security-verify.com', 'twitter-verify-support.com',
      // Indian banking
      'sbi-secure.com', 'sbi-verify.com', 'onlinesbi-secure.net',
      'hdfc-secure.com', 'hdfc-verify.com', 'hdfc-login.net',
      'icici-secure.com', 'icici-verify.com', 'icici-online.net',
      'axis-secure.com', 'axis-verify.com', 'axis-login.net',
      'kotak-secure.com', 'kotak-verify.com', 'kotak-online.net',
      // UPI/Payment apps
      'paytm-secure.com', 'paytm-verify.com', 'paytm-login.net',
      'phonepe-secure.com', 'phonepe-verify.com', 'phonepe-login.net',
      'gpay-secure.com', 'gpay-verify.com', 'googlepay-login.net',
      // Indian government
      'irs-tax-refund.com', 'gov-refund.com', 'uidai-secure.com',
      'aadhaar-verify.com', 'epf-secure.com', 'epfo-verify.com',
      // Generic
      'account-suspended.com', 'password-expired.com', 'security-alert.com',
      'verify-now.com', 'confirm-account.com', 'update-payment.com',
    ]);
  }

  bool _isLegitimateDomain(String domain) {
    final lowerDomain = domain.toLowerCase();

    // Check exact match
    if (_whitelist.contains(lowerDomain)) return true;

    // Check with www prefix
    if (!lowerDomain.startsWith('www.') && _whitelist.contains('www.$lowerDomain')) {
      return true;
    }

    // Check if domain matches known legitimate patterns
    for (final legitimate in _whitelist) {
      if (lowerDomain == legitimate) return true;
    }

    return false;
  }

  Future<PhishingDetectionResult> detect(String url) async {
    if (!_isInitialized) await initialize();

    final findings = <DetectionFinding>[];
    int threatScore = 0;

    try {
      final processedUrl = _normalizeUrl(url);
      final uri = Uri.parse(processedUrl);
      final domain = uri.host.toLowerCase();
      final fullUrl = processedUrl.toLowerCase();

      // FIRST: Check if this is a known legitimate domain
      if (_isLegitimateDomain(domain)) {
        return PhishingDetectionResult(
          url: processedUrl,
          isPhishing: false,
          riskLevel: RiskLevel.safe,
          threatScore: 0,
          findings: [],
          reason: 'This is a known legitimate domain.',
        );
      }

      // 1. Blacklist check
      if (_isInBlacklist(domain)) {
        findings.add(DetectionFinding(
          type: DetectionType.blacklist,
          severity: Severity.critical,
          description: 'Domain found in known phishing blacklist',
          score: 60,
        ));
        threatScore += 60;
      }

      // 2. IP address check
      if (_isIpAddress(domain)) {
        findings.add(DetectionFinding(
          type: DetectionType.ipAddress,
          severity: Severity.critical,
          description: 'URL uses IP address instead of domain name',
          score: 35,
        ));
        threatScore += 35;
      }

      // 3. @ symbol check
      if (fullUrl.contains('@')) {
        findings.add(DetectionFinding(
          type: DetectionType.redirect,
          severity: Severity.critical,
          description: 'URL contains @ symbol (possible redirect attack)',
          score: 35,
        ));
        threatScore += 35;
      }

      // 4. URL shortener detection
      final shortener = _detectUrlShortener(domain);
      if (shortener != null) {
        findings.add(DetectionFinding(
          type: DetectionType.urlShortener,
          severity: Severity.high,
          description: 'URL shortener detected ($shortener) - may hide true destination',
          score: 20,
        ));
        threatScore += 20;
      }

      // 5. Suspicious TLD
      final tld = _getTld(domain);
      if (_suspiciousTLDs.contains(tld)) {
        findings.add(DetectionFinding(
          type: DetectionType.suspiciousTLD,
          severity: Severity.high,
          description: 'Suspicious or free TLD (.$tld) often used in phishing',
          score: 20,
        ));
        threatScore += 20;
      }

      // 6. Double extensions
      if (RegExp(r'\.(php|html?|asp|jsp|aspx)\.(php|html?|asp|jsp|aspx)$',
          caseSensitive: false).hasMatch(fullUrl)) {
        findings.add(DetectionFinding(
          type: DetectionType.doubleExtension,
          severity: Severity.high,
          description: 'Suspicious double file extension detected',
          score: 15,
        ));
        threatScore += 15;
      }

      // 7. Typosquatting - Indian Banks
      final bankTyposquat = _detectIndianBankTyposquatting(domain);
      if (bankTyposquat != null) {
        findings.add(DetectionFinding(
          type: DetectionType.typosquatting,
          severity: Severity.critical,
          description: 'Possible bank impersonation: $bankTyposquat',
          score: 40,
        ));
        threatScore += 40;
      }

      // 8. Bank name with suspicious keywords
      if (_hasBankWithKeywords(domain)) {
        findings.add(DetectionFinding(
          type: DetectionType.brandSubdomain,
          severity: Severity.critical,
          description: 'Bank name combined with suspicious keywords',
          score: 35,
        ));
        threatScore += 35;
      }

      // 9. Typosquatting - Payment Apps
      final paymentTyposquat = _detectPaymentAppTyposquatting(domain);
      if (paymentTyposquat != null) {
        findings.add(DetectionFinding(
          type: DetectionType.typosquatting,
          severity: Severity.critical,
          description: 'Possible payment app impersonation: $paymentTyposquat',
          score: 40,
        ));
        threatScore += 40;
      }

      // 10. Typosquatting - Indian Government
      final govTyposquat = _detectGovernmentTyposquatting(domain);
      if (govTyposquat != null) {
        findings.add(DetectionFinding(
          type: DetectionType.typosquatting,
          severity: Severity.critical,
          description: 'Possible impersonation of Indian government service: $govTyposquat',
          score: 40,
        ));
        threatScore += 40;
      }

      // 11. Typosquatting - Global brands
      final brandTyposquat = _detectBrandTyposquatting(domain);
      if (brandTyposquat != null) {
        findings.add(DetectionFinding(
          type: DetectionType.typosquatting,
          severity: Severity.high,
          description: 'Possible typosquatting: $brandTyposquat',
          score: 35,
        ));
        threatScore += 35;
      }

      // 12. Levenshtein distance detection
      final levenshteinTyposquat = _detectLevenshteinTyposquatting(domain);
      if (levenshteinTyposquat != null) {
        findings.add(DetectionFinding(
          type: DetectionType.typosquatting,
          severity: Severity.high,
          description: 'Possible typosquatting: $levenshteinTyposquat',
          score: 35,
        ));
        threatScore += 35;
      }

      // 13. Suspicious keywords
      final keywordCount = _countSuspiciousKeywords(domain);
      if (keywordCount >= 2) {
        findings.add(DetectionFinding(
          type: DetectionType.suspiciousKeywords,
          severity: Severity.medium,
          description: 'Multiple suspicious keywords in domain ($keywordCount found)',
          score: keywordCount * 8,
        ));
        threatScore += keywordCount * 8;
      } else if (keywordCount == 1) {
        findings.add(DetectionFinding(
          type: DetectionType.suspiciousKeywords,
          severity: Severity.low,
          description: 'Suspicious keyword found in domain',
          score: 8,
        ));
        threatScore += 8;
      }

      // 14. URL length
      if (fullUrl.length > 100) {
        findings.add(DetectionFinding(
          type: DetectionType.urlLength,
          severity: Severity.low,
          description: 'Unusually long URL (${fullUrl.length} characters)',
          score: 5,
        ));
        threatScore += 5;
      }

      // 15. Excessive subdomains
      final subdomainCount = domain.split('.').length - 2;
      if (subdomainCount > 3) {
        findings.add(DetectionFinding(
          type: DetectionType.excessiveSubdomains,
          severity: Severity.low,
          description: 'Excessive subdomains ($subdomainCount)',
          score: 5,
        ));
        threatScore += 5;
      }

      // 16. Numeric domain
      if (RegExp(r'^[0-9.-]+\.[a-z]+$').hasMatch(domain)) {
        findings.add(DetectionFinding(
          type: DetectionType.numericDomain,
          severity: Severity.medium,
          description: 'Domain contains mostly numbers',
          score: 10,
        ));
        threatScore += 10;
      }

      // 17. Punycode detection
      if (domain.contains('xn--') || fullUrl.contains('xn--')) {
        findings.add(DetectionFinding(
          type: DetectionType.punycode,
          severity: Severity.high,
          description: 'Punycode detected - possible homograph attack',
          score: 25,
        ));
        threatScore += 25;
      }

      // 18. Long URL path
      if (uri.path.length > 80) {
        findings.add(DetectionFinding(
          type: DetectionType.longPath,
          severity: Severity.low,
          description: 'Suspiciously long URL path',
          score: 5,
        ));
        threatScore += 5;
      }

      // 19. Missing HTTPS (only for suspicious domains)
      if (!fullUrl.startsWith('https:')) {
        findings.add(DetectionFinding(
          type: DetectionType.missingHTTPS,
          severity: Severity.low,
          description: 'URL does not use secure HTTPS protocol',
          score: 8,
        ));
        threatScore += 8;
      }

      // 20. High entropy domain
      if (_hasHighEntropy(domain)) {
        findings.add(DetectionFinding(
          type: DetectionType.highEntropy,
          severity: Severity.low,
          description: 'Domain has random-looking characters',
          score: 8,
        ));
        threatScore += 8;
      }

      // 21. Brand in subdomain
      if (_hasBrandInSubdomain(domain)) {
        findings.add(DetectionFinding(
          type: DetectionType.brandSubdomain,
          severity: Severity.high,
          description: 'Brand name in subdomain (e.g., paytm.secure-domain.com)',
          score: 25,
        ));
        threatScore += 25;
      }

      // 22. APK download link
      if (fullUrl.endsWith('.apk') || fullUrl.contains('.apk?')) {
        findings.add(DetectionFinding(
          type: DetectionType.apkDownload,
          severity: Severity.critical,
          description: 'APK file download link detected - possible fake app',
          score: 40,
        ));
        threatScore += 40;
      }

      // 23. Port number check
      if (uri.port != 0 && uri.port != 80 && uri.port != 443) {
        findings.add(DetectionFinding(
          type: DetectionType.nonStandardPort,
          severity: Severity.medium,
          description: 'Non-standard port (${uri.port}) detected',
          score: 15,
        ));
        threatScore += 15;
      }

      // 24. Urgency language
      if (_hasIndianUrgencyLanguage(fullUrl)) {
        findings.add(DetectionFinding(
          type: DetectionType.urgency,
          severity: Severity.high,
          description: 'Urgent language typical of phishing detected',
          score: 20,
        ));
        threatScore += 20;
      }

      // 25. Prize/Lottery scam patterns
      if (_hasPrizeLotteryScam(fullUrl)) {
        findings.add(DetectionFinding(
          type: DetectionType.urgency,
          severity: Severity.high,
          description: 'Prize/lottery scam language detected',
          score: 25,
        ));
        threatScore += 25;
      }

      // 26. Delivery scam patterns
      if (_hasDeliveryScam(fullUrl)) {
        findings.add(DetectionFinding(
          type: DetectionType.urgency,
          severity: Severity.high,
          description: 'Parcel/courier scam language detected',
          score: 20,
        ));
        threatScore += 20;
      }

      // 27. Suspicious URL paths
      if (_hasSuspiciousPath(uri.path)) {
        findings.add(DetectionFinding(
          type: DetectionType.suspiciousKeywords,
          severity: Severity.medium,
          description: 'Suspicious URL path detected',
          score: 15,
        ));
        threatScore += 15;
      }

      // Calculate risk level
      final riskLevel = _calculateRiskLevel(threatScore);

      return PhishingDetectionResult(
        url: processedUrl,
        isPhishing: riskLevel.index >= RiskLevel.high.index,
        riskLevel: riskLevel,
        threatScore: threatScore,
        findings: findings,
        reason: findings.isNotEmpty
            ? findings.map((f) => f.description).join('. ')
            : 'No suspicious patterns detected. URL appears legitimate.',
      );

    } catch (e) {
      return PhishingDetectionResult(
        url: url,
        isPhishing: false,
        riskLevel: RiskLevel.unknown,
        threatScore: 0,
        findings: [],
        reason: 'Error analyzing URL: ${e.toString()}',
      );
    }
  }

  String _normalizeUrl(String url) {
    if (!url.startsWith('http')) {
      return 'https://$url';
    }
    return url;
  }

  bool _isInBlacklist(String domain) {
    if (_blacklist.contains(domain)) return true;

    if (domain.startsWith('www.')) {
      if (_blacklist.contains(domain.substring(4))) return true;
    } else {
      if (_blacklist.contains('www.$domain')) return true;
    }

    for (final blocked in _blacklist) {
      if (domain.contains(blocked) || blocked.contains(domain)) {
        return true;
      }
    }

    return false;
  }

  bool _isIpAddress(String domain) {
    return RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(domain);
  }

  String? _detectUrlShortener(String domain) {
    for (final shortener in _urlShorteners) {
      if (domain.contains(shortener)) {
        return shortener;
      }
    }
    return null;
  }

  String _getTld(String domain) {
    final parts = domain.split('.');
    return parts.isNotEmpty ? parts.last : '';
  }

  String? _detectIndianBankTyposquatting(String domain) {
    for (final category in _indianBanks.values) {
      for (final brand in category) {
        if (domain.contains(brand)) {
          // Check if it's the official domain
          if (domain == '$brand.com' || domain == '$brand.in' ||
              domain == 'onlinesbi.in' || domain == 'hdfcbank.com' ||
              domain == 'icicibank.com' || domain == 'axisbank.com' ||
              domain == 'kotak.com') {
            continue;
          }

          // Check for typosquatting
          final typos = _generateTypos(brand);
          for (final typo in typos) {
            if (domain.contains(typo)) {
              return '"$typo" looks like "$brand"';
            }
          }

          // Brand in domain but not official = suspicious
          return '"$domain" contains "$brand" but is not the official domain';
        }
      }
    }
    return null;
  }

  String? _detectPaymentAppTyposquatting(String domain) {
    final paymentApps = ['paytm', 'phonepe', 'googlepay', 'gpay', 'bhim', 'mobikwik', 'freecharge'];
    for (final app in paymentApps) {
      if (domain.contains(app)) {
        if (domain == '$app.com' || domain == '$app.in' || domain == 'paytm.com') {
          continue;
        }

        final typos = _generateTypos(app);
        for (final typo in typos) {
          if (domain.contains(typo)) {
            return '"$typo" looks like "$app"';
          }
        }

        return '"$domain" contains "$app" but is not the official domain';
      }
    }
    return null;
  }

  String? _detectGovernmentTyposquatting(String domain) {
    final govServices = ['uidai', 'aadhaar', 'income', 'tax', 'epf', 'epfo', 'gov', 'india'];
    for (final service in govServices) {
      if (domain.contains(service)) {
        if (domain == '$service.gov.in' || domain == '$service.nic.in' ||
            domain == 'uidai.gov.in' || domain == 'incometax.gov.in' ||
            domain == 'epfindia.gov.in' || domain == 'india.gov.in') {
          continue;
        }

        final typos = _generateTypos(service);
        for (final typo in typos) {
          if (domain.contains(typo)) {
            return '"$typo" impersonates government service';
          }
        }

        return '"$domain" contains "$service" but is not the official government domain';
      }
    }
    return null;
  }

  String? _detectBrandTyposquatting(String domain) {
    for (final brand in _globalBrands) {
      if (domain.contains(brand)) {
        if (domain == '$brand.com' || domain == 'google.com' ||
            domain == 'microsoft.com' || domain == 'apple.com' ||
            domain == 'netflix.com' || domain == 'facebook.com' ||
            domain == 'instagram.com' || domain == 'paypal.com') {
          continue;
        }

        final typos = _generateTypos(brand);
        for (final typo in typos) {
          if (domain.contains(typo)) {
            return '"$typo" looks like "$brand"';
          }
        }

        return '"$domain" contains "$brand" but is not the official domain';
      }
    }
    return null;
  }

  List<String> _generateTypos(String brand) {
    final typos = <String>[];

    // Number substitution
    final substitutions = {'a': '4', 'e': '3', 'i': '1', 'o': '0', 's': '5'};
    for (final entry in substitutions.entries) {
      typos.add(brand.replaceAll(entry.key, entry.value));
    }

    // Number prefix/suffix
    for (int i = 1; i <= 5; i++) {
      typos.add('$brand$i');
      typos.add('$i$brand');
    }

    // Keyword addition
    typos.add('$brand-secure');
    typos.add('$brand-login');
    typos.add('$brand-verify');
    typos.add('$brand-support');
    typos.add('secure-$brand');
    typos.add('login-$brand');
    typos.add('verify-$brand');
    typos.add('official-$brand');
    typos.add('my$brand');
    typos.add('${brand}update');
    typos.add('${brand}account');
    typos.add('${brand}wallet');

    return typos;
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
    final brands = [
      ..._indianBanks.values.expand((e) => e),
      'paytm', 'phonepe', 'googlepay', 'gpay', 'bhim', 'aadhaar', 'uidai',
      ..._globalBrands,
    ];

    final cleanDomain = domain.split('.').first;

    for (final brand in brands) {
      if (brand.length < 4) continue;

      final distance = _levenshteinDistance(cleanDomain, brand);
      final maxDistance = (brand.length * 0.3).floor() + 1;

      if (distance > 0 && distance <= maxDistance) {
        return '"$domain" is $distance edit(s) away from "$brand"';
      }
    }
    return null;
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
    final allBrands = [
      ..._indianBanks.values.expand((e) => e),
      'paytm', 'phonepe', 'googlepay', 'gpay', 'bhim', 'aadhaar', 'uidai',
      ..._globalBrands,
    ];

    for (final brand in allBrands) {
      if (brand.length < 4) continue;
      if (subdomain.contains(brand.toLowerCase()) &&
          mainDomain != brand.toLowerCase()) {
        return true;
      }
    }

    return false;
  }

  bool _hasBankWithKeywords(String domain) {
    final bankKeywords = ['secure', 'login', 'verify', 'update', 'support', 'account', 'alert', 'confirm'];
    final allBanks = [
      ..._indianBanks.values.expand((e) => e),
      'paytm', 'phonepe', 'googlepay', 'gpay', 'bhim',
    ];

    for (final bank in allBanks) {
      for (final keyword in bankKeywords) {
        if (domain.contains('$bank-$keyword') || domain.contains('$bank$keyword') ||
            domain.contains('$keyword-$bank') || domain.contains('$keyword$bank')) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasIndianUrgencyLanguage(String url) {
    final urgencyPatterns = [
      'urgent', 'immediately', 'within 24 hours', 'account suspended',
      'account blocked', 'kyc pending', 'aadhaar', 'pan card',
      'bank account', 'debit card', 'credit card', 'otp', 'mpin',
      'upi pin', 'cvv', 'verify your account', 'complete kyc',
      'update now', 'final notice', 'last warning', 'click here',
      'turant', 'jaldi', 'abhi', 'aapka khata', 'band ho jayega',
    ];

    for (final pattern in urgencyPatterns) {
      if (url.toLowerCase().contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  bool _hasPrizeLotteryScam(String url) {
    final patterns = [
      'you\'ve won', 'you have won', 'congratulations', 'winner',
      'selected for', 'lottery', 'prize', 'cashback', '₹', 'rs ',
      'rupees', 'free iphone', 'free samsung', 'free recharge',
    ];
    final lowerUrl = url.toLowerCase();
    for (final pattern in patterns) {
      if (lowerUrl.contains(pattern)) {
        return true;
      }
    }
    return false;
  }

  bool _hasDeliveryScam(String url) {
    final patterns = [
      'parcel', 'courier', 'package', 'shipment', 'waiting',
      'detained', 'customs', 'clearance', 'delivery charge',
      'delivery fee', 'package pending', 'parcel pending',
    ];
    final lowerUrl = url.toLowerCase();
    for (final pattern in patterns) {
      if (lowerUrl.contains(pattern)) {
        return true;
      }
    }
    return false;
  }

  bool _hasSuspiciousPath(String path) {
    final suspiciousPaths = [
      '/verify', '/confirm', '/update', '/secure', '/validate',
      '/signin', '/login', '/account', '/kyc', '/details',
      '/verify-account', '/confirm-identity', '/update-kyc',
      '/secure-login', '/account-verify', '/wallet-verify',
    ];
    final lowerPath = path.toLowerCase();
    for (final p in suspiciousPaths) {
      if (lowerPath.contains(p)) {
        return true;
      }
    }
    return false;
  }

  bool _hasHighEntropy(String domain) {
    final cleanDomain = domain.replaceAll(RegExp(r'\.[a-z]+$'), '').replaceAll('.', '');
    if (cleanDomain.length < 8) return false;

    final uniqueChars = cleanDomain.split('').toSet().length;
    final length = cleanDomain.length;

    return uniqueChars > length * 0.7;
  }

  RiskLevel _calculateRiskLevel(int score) {
    if (score >= 80) return RiskLevel.critical;
    if (score >= 50) return RiskLevel.high;
    if (score >= 25) return RiskLevel.medium;
    if (score >= 10) return RiskLevel.low;
    return RiskLevel.safe;
  }

  Future<String> getDetailedAnalysis(String url) async {
    final result = await detect(url);
    final buffer = StringBuffer();

    buffer.writeln('URL Security Analysis Report');
    buffer.writeln('═' * 40);
    buffer.writeln();
    buffer.writeln('URL: $url');
    buffer.writeln('Risk Level: ${result.riskLevel.name.toUpperCase()}');
    buffer.writeln('Threat Score: ${result.threatScore}/100');
    buffer.writeln();

    if (result.findings.isEmpty) {
      buffer.writeln('No threats detected');
      buffer.writeln('The URL appears to be safe based on our analysis.');
    } else {
      buffer.writeln('Threats Found (${result.findings.length}):');
      buffer.writeln();

      final sortedFindings = List<DetectionFinding>.from(result.findings)
        ..sort((a, b) => b.severity.index.compareTo(a.severity.index));

      for (final finding in sortedFindings) {
        final icon = _getSeverityIcon(finding.severity);
        buffer.writeln('$icon ${finding.description}');
        buffer.writeln('   Severity: ${finding.severity.name} | Score: +${finding.score}');
        buffer.writeln();
      }
    }

    buffer.writeln('─' * 40);
    buffer.writeln('Generated by SecureScan - 100% Local Analysis');

    return buffer.toString();
  }

  String _getSeverityIcon(Severity severity) {
    switch (severity) {
      case Severity.critical: return '🚨';
      case Severity.high: return '⚠️';
      case Severity.medium: return '⚡';
      case Severity.low: return 'ℹ️';
      case Severity.info: return '✓';
    }
  }
}

enum DetectionType {
  blacklist, ipAddress, redirect, urlShortener, suspiciousTLD,
  doubleExtension, typosquatting, suspiciousKeywords, urlLength,
  excessiveSubdomains, numericDomain, punycode, longPath, missingHTTPS,
  highEntropy, brandSubdomain, urgency, apkDownload, nonStandardPort,
}

enum Severity { info, low, medium, high, critical }

enum RiskLevel { safe, low, medium, high, critical, unknown }

class DetectionFinding {
  final DetectionType type;
  final Severity severity;
  final String description;
  final int score;

  DetectionFinding({
    required this.type,
    required this.severity,
    required this.description,
    required this.score,
  });
}

class PhishingDetectionResult {
  final String url;
  final bool isPhishing;
  final RiskLevel riskLevel;
  final int threatScore;
  final List<DetectionFinding> findings;
  final String reason;

  PhishingDetectionResult({
    required this.url,
    required this.isPhishing,
    required this.riskLevel,
    required this.threatScore,
    required this.findings,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'isPhishing': isPhishing,
      'riskLevel': riskLevel.name,
      'threatScore': threatScore,
      'findings': findings.map((f) => {
        'type': f.type.name,
        'severity': f.severity.name,
        'description': f.description,
        'score': f.score,
      }).toList(),
      'reason': reason,
    };
  }
}
