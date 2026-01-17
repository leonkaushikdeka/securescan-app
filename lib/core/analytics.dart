import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'logger.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    this.parameters = const {},
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'parameters': parameters,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  String? _userId;
  String? _sessionId;
  final List<AnalyticsEvent> _events = [];
  bool _enabled = !kDebugMode;
  bool _consentGiven = false;

  void initialize() {
    if (_enabled && _consentGiven) {
      _sessionId = const Uuid().v4();
      appLogger.i('Analytics initialized - Session: $_sessionId');
    }
  }

  void setConsent(bool consent) {
    _consentGiven = consent;
    if (consent) {
      initialize();
    }
  }

  void setUserId(String userId) {
    _userId = userId;
  }

  void logEvent(String name, [Map<String, dynamic>? parameters]) {
    if (!_enabled || !_consentGiven) return;

    final event = AnalyticsEvent(
      name: name,
      parameters: parameters ?? {},
    );
    _events.add(event);

    // Keep only last 100 events
    if (_events.length > 100) {
      _events.removeAt(0);
    }

    appLogger.d('Event logged: $name');

    // TODO: Send to analytics backend (Firebase, Mixpanel, Amplitude, etc.)
    // Example: FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
  }

  // Predefined events for the app
  void logDeepfakeScan({
    required bool isDeepfake,
    required double confidence,
    required String imageSource,
    Duration? processingTime,
  }) {
    logEvent('deepfake_scan', {
      'is_deepfake': isDeepfake,
      'confidence': confidence,
      'image_source': imageSource,
      'processing_time_ms': processingTime?.inMilliseconds,
    });
  }

  void logPhishingScan({
    required String riskLevel,
    required int threatScore,
    required String url,
  }) {
    logEvent('phishing_scan', {
      'risk_level': riskLevel,
      'threat_score': threatScore,
      'url_length': url.length,
    });
  }

  void logFeatureUse(String featureName) {
    logEvent('feature_use', {
      'feature': featureName,
    });
  }

  void logSettingsChange(String settingName, dynamic value) {
    logEvent('settings_change', {
      'setting': settingName,
      'value': value.toString(),
    });
  }

  void logError(String errorType, String message) {
    logEvent('error', {
      'error_type': errorType,
      'message': message,
    });
  }

  List<AnalyticsEvent> getEvents() => List.unmodifiable(_events);

  Future<void> flush() async {
    if (_events.isEmpty) return;

    appLogger.i('Flushing ${_events.length} analytics events');

    // TODO: Send all pending events to backend
    // await _sendToBackend(_events.toList());

    _events.clear();
  }

  Map<String, dynamic> getAnalyticsSummary() {
    final eventCounts = <String, int>{};
    for (final event in _events) {
      eventCounts[event.name] = (eventCounts[event.name] ?? 0) + 1;
    }

    return {
      'sessionId': _sessionId,
      'totalEvents': _events.length,
      'eventCounts': eventCounts,
      'startTime': _events.isNotEmpty ? _events.first.timestamp.toIso8601String() : null,
      'endTime': _events.isNotEmpty ? _events.last.timestamp.toIso8601String() : null,
    };
  }
}

final analyticsService = AnalyticsService();
