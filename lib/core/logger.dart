import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  bool _enableConsole = kDebugMode;
  bool _enableFile = false;
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  void configure({
    bool enableConsole = true,
    bool enableFile = false,
    LogLevel minLevel = LogLevel.debug,
  }) {
    _enableConsole = enableConsole;
    _enableFile = enableFile;
    _minLevel = minLevel;
  }

  void _log(LogLevel level, String message, [dynamic error, StackTrace? stackTrace]) {
    if (level.index < _minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(8);
    final logMessage = '[$timestamp] [$levelStr] $message';

    if (_enableConsole) {
      if (level == LogLevel.error || level == LogLevel.critical) {
        // ignore: avoid_print
        print('$logMessage${error != null ? '\nError: $error' : ''}');
        if (stackTrace != null) {
          // ignore: avoid_print
          print('StackTrace: $stackTrace');
        }
      } else {
        // ignore: avoid_print
        print(logMessage);
      }
    }

    // TODO: Implement file logging if needed
    // if (_enableFile) {
    //   _writeToFile(logMessage);
    // }
  }

  void d(String message, [dynamic error, StackTrace? stackTrace]) =>
      _log(LogLevel.debug, message, error, stackTrace);

  void i(String message, [dynamic error, StackTrace? stackTrace]) =>
      _log(LogLevel.info, message, error, stackTrace);

  void w(String message, [dynamic error, StackTrace? stackTrace]) =>
      _log(LogLevel.warning, message, error, stackTrace);

  void e(String message, [dynamic error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  void c(String message, [dynamic error, StackTrace? stackTrace]) =>
      _log(LogLevel.critical, message, error, stackTrace);
}

final appLogger = AppLogger();
