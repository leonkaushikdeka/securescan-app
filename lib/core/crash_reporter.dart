import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'logger.dart';

class CrashReporter {
  static final CrashReporter _instance = CrashReporter._internal();
  factory CrashReporter() => _instance;
  CrashReporter._internal();

  String? _userId;
  String? _sessionId;
  int _crashCount = 0;
  bool _enabled = !kDebugMode;

  void initialize() {
    if (_enabled) {
      _sessionId = const Uuid().v4();
      _userId = null;
      _crashCount = 0;
      appLogger.i('Crash reporter initialized - Session: $_sessionId');
    }
  }

  void setUserId(String userId) {
    if (_enabled) {
      _userId = userId;
    }
  }

  void trackError(
    String errorType,
    String message, {
    String? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    if (!_enabled) return;

    _crashCount++;
    final event = {
      'id': const Uuid().v4(),
      'sessionId': _sessionId,
      'userId': _userId,
      'timestamp': DateTime.now().toIso8601String(),
      'errorType': errorType,
      'message': message,
      'stackTrace': stackTrace,
      'metadata': metadata,
      'crashCount': _crashCount,
      'platform': Platform.operatingSystem,
      'appVersion': '1.0.0',
    };

    // In production, send to crash reporting service
    // For now, log it
    appLogger.e('Error tracked: $errorType - $message', event);

    // TODO: Integrate with Firebase Crashlytics, Sentry, or Bugsnag
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  void trackNonFatalException(
    dynamic exception,
    StackTrace stackTrace, {
    Map<String, dynamic>? metadata,
  }) {
    trackError(
      exception.runtimeType.toString(),
      exception.toString(),
      stackTrace: stackTrace.toString(),
      metadata: metadata,
    );
  }

  void trackFatalError(dynamic error, StackTrace stackTrace) {
    trackError(
      'FatalError',
      error.toString(),
      stackTrace: stackTrace.toString(),
      metadata: {'isFatal': true},
    );
  }

  int getCrashCount() => _crashCount;
  String? getSessionId() => _sessionId;

  Future<void> reportAppStartTime(Duration startTime) async {
    if (!_enabled) return;

    final event = {
      'type': 'performance',
      'subtype': 'app_start',
      'sessionId': _sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'startTimeMs': startTime.inMilliseconds,
    };

    appLogger.i('App start time: ${startTime.inMilliseconds}ms');
    // TODO: Send to analytics
  }

  Future<void> reportScreenView(String screenName, Duration duration) async {
    if (!_enabled) return;

    final event = {
      'type': 'analytics',
      'subtype': 'screen_view',
      'sessionId': _sessionId,
      'screenName': screenName,
      'durationMs': duration.inMilliseconds,
    };

    // TODO: Send to analytics service
  }
}

final crashReporter = CrashReporter();
