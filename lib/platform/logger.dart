import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Log severity.
enum LogLevel { debug, info, warning, error, fatal }

/// Global logging, crash reporting, and telemetry facade.
///
/// Relationships (C4):
///   Logging + Error Boundary → UI : protects with error boundaries
class AppLogger {
  AppLogger._();

  static final List<LogEntry> _buffer = [];

  /// Structured log.
  static void log(LogLevel level, String message,
      {Map<String, dynamic>? context}) {
    final entry = LogEntry(
      level: level,
      message: message,
      context: context,
      timestamp: DateTime.now(),
    );
    _buffer.add(entry);
    if (_buffer.length > 500) _buffer.removeAt(0);

    if (kDebugMode) {
      developer.log(
        '[${ level.name.toUpperCase()}] $message',
        name: 'ComfortOS',
      );
    }
  }

  /// Report an unhandled error / crash.
  static void reportCrash(Object error, StackTrace stackTrace) {
    log(LogLevel.fatal, error.toString(), context: {
      'stackTrace': stackTrace.toString(),
    });
    // In production this would forward to Sentry / Crashlytics.
    if (kDebugMode) {
      developer.log(
        'CRASH: $error\n$stackTrace',
        name: 'ComfortOS',
        level: 1000,
      );
    }
  }

  /// Telemetry / analytics event.
  static void telemetry(String event, {Map<String, dynamic>? properties}) {
    log(LogLevel.info, 'TELEMETRY: $event', context: properties);
  }

  /// Access the in-memory log buffer (useful for debug screens).
  static List<LogEntry> get buffer => List.unmodifiable(_buffer);
}

/// Single log entry.
class LogEntry {
  final LogLevel level;
  final String message;
  final Map<String, dynamic>? context;
  final DateTime timestamp;

  const LogEntry({
    required this.level,
    required this.message,
    this.context,
    required this.timestamp,
  });
}
