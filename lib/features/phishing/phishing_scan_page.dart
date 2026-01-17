import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'phishing_detector_service.dart';
import '../../core/analytics.dart';
import '../../main.dart';

class PhishingScanPage extends StatefulWidget {
  const PhishingScanPage({super.key});

  @override
  State<PhishingScanPage> createState() => _PhishingScanPageState();
}

class _PhishingScanPageState extends State<PhishingScanPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isInitialized = false;
  bool _isProcessing = false;
  PhishingDetectionResult? _result;
  String _statusMessage = 'Initializing...';
  final PhishingDetectorService _detector = PhishingDetectorService();

  @override
  void initState() {
    super.initState();
    _initializeDetector();
  }

  Future<void> _initializeDetector() async {
    setState(() => _statusMessage = 'Loading detection engine...');
    try {
      await _detector.initialize();
      setState(() {
        _isInitialized = true;
        _statusMessage = 'Ready to scan';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Initialization failed');
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
    if (url == null) _urlController.text = inputUrl;

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
        confidence: 1.0 - (result.threatScore / 100),
        details: result.reason,
      );

      setState(() {
        _result = result;
        _isProcessing = false;
        _statusMessage = result.isPhishing ? 'Phishing detected!' : 'URL appears legitimate';
      });

      analyticsService.logPhishingScan(
        riskLevel: result.riskLevel.name,
        threatScore: result.threatScore,
        url: processedUrl,
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Scan failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.critical: return Colors.red;
      case RiskLevel.high: return Colors.orange;
      case RiskLevel.medium: return Colors.yellow.shade700;
      case RiskLevel.low: return Colors.green;
      case RiskLevel.safe: return Colors.green;
      default: return Colors.grey;
    }
  }

  String _getRiskEmoji(RiskLevel level) {
    switch (level) {
      case RiskLevel.critical: return '🚨';
      case RiskLevel.high: return '⚠️';
      case RiskLevel.medium: return '⚡';
      case RiskLevel.low: return '✅';
      case RiskLevel.safe: return '✅';
      default: return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'Enter URL (e.g., example.com)',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data != null && data.text != null) {
                    _urlController.text = data.text!;
                    _scanUrl();
                  }
                },
              ),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _scanUrl(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isInitialized && !_isProcessing ? () => _scanUrl() : null,
              icon: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.security),
              label: const Text('SCAN URL'),
            ),
          ),
          const SizedBox(height: 16),
          Text(_statusMessage, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
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
                            Text(_getRiskEmoji(_result!.riskLevel), style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _result!.isPhishing ? 'PHISHING RISK' : 'URL APPEARS SAFE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: _getRiskColor(_result!.riskLevel),
                                    ),
                                  ),
                                  Text(
                                    'Risk Level: ${_result!.riskLevel.name.toUpperCase()} (${_result!.threatScore} points)',
                                    style: TextStyle(color: _getRiskColor(_result!.riskLevel)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_result!.findings.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text('Threats Found (${_result!.findings.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ..._result!.findings.map((finding) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  finding.severity == RiskLevel.critical ? Icons.error : Icons.warning,
                                  size: 16,
                                  color: _getRiskColor(finding.severity),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    finding.description,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _result!.reason,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
