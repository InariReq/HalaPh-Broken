import 'dart:developer' as developer;

/// Production monitoring service for error tracking and performance monitoring
class MonitoringService {
  static bool _initialized = false;
  static String? _userId;
  static final Map<String, Object> _customKeys = {};

  /// Initialize monitoring services
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      _initialized = true;
      developer.log('MonitoringService: Initialized successfully');
    } catch (e) {
      developer.log('MonitoringService: Initialization failed: $e');
    }
  }

  /// Log custom event for analytics
  static void logEvent(String name, {Map<String, Object>? parameters}) {
    if (!_initialized) return;

    try {
      developer.log('Event: $name', name: 'MonitoringService');
      if (parameters != null) {
        developer.log('Parameters: $parameters', name: 'MonitoringService');
      }
    } catch (e) {
      developer.log('Failed to log event: $e', name: 'MonitoringService');
    }
  }

  /// Log error with context
  static void logError(
    dynamic exception,
    StackTrace stackTrace, {
    String? context,
    Map<String, Object>? parameters,
  }) {
    if (!_initialized) return;

    try {
      // Log to console with full context
      final buffer = StringBuffer();
      buffer.writeln('Error: $exception');
      if (context != null) buffer.writeln('Context: $context');
      if (parameters != null) buffer.writeln('Parameters: $parameters');
      buffer.writeln('User: $_userId');
      buffer.writeln('Custom Keys: $_customKeys');

      developer.log(buffer.toString(),
          name: 'MonitoringService', error: exception, stackTrace: stackTrace);
    } catch (e) {
      developer.log('Failed to log error: $e', name: 'MonitoringService');
    }
  }

  /// Log performance metric
  static void logPerformance(String metricName, int durationMs) {
    if (!_initialized) return;

    try {
      developer.log('Performance: $metricName = ${durationMs}ms',
          name: 'MonitoringService');
    } catch (e) {
      developer.log('Failed to log performance: $e', name: 'MonitoringService');
    }
  }

  /// Start performance trace
  static PerformanceTrace startTrace(String name) {
    if (!_initialized) {
      return PerformanceTrace(name);
    }

    try {
      return PerformanceTrace(name);
    } catch (e) {
      developer.log('Failed to start trace: $e', name: 'MonitoringService');
      return PerformanceTrace(name);
    }
  }

  /// Set user identifier for crash reporting
  static void setUserIdentifier(String userId) {
    if (!_initialized) return;

    try {
      _userId = userId;
      developer.log('User identifier set: $userId', name: 'MonitoringService');
    } catch (e) {
      developer.log('Failed to set user identifier: $e',
          name: 'MonitoringService');
    }
  }

  /// Set custom key/value for crash reporting
  static void setCustomKey(String key, Object value) {
    if (!_initialized) return;

    try {
      _customKeys[key] = value;
      developer.log('Custom key set: $key = $value', name: 'MonitoringService');
    } catch (e) {
      developer.log('Failed to set custom key: $e', name: 'MonitoringService');
    }
  }
}

/// Simple performance trace implementation
class PerformanceTrace {
  final String name;
  final Stopwatch _stopwatch = Stopwatch();

  PerformanceTrace(this.name);

  /// Start the trace
  Future<void> start() async {
    _stopwatch.start();
    developer.log('Trace started: $name', name: 'MonitoringService');
  }

  /// Stop the trace and log the duration
  Future<void> stop() async {
    _stopwatch.stop();
    final duration = _stopwatch.elapsedMilliseconds;
    developer.log('Trace stopped: $name = ${duration}ms',
        name: 'MonitoringService');
  }

  /// Set a metric (no-op in this simple implementation)
  void setMetric(String name, int value) {
    developer.log('Metric: $name = $value', name: 'MonitoringService');
  }

  /// Increment a metric (no-op in this simple implementation)
  void incrementMetric(String name, int value) {
    developer.log('Increment metric: $name += $value',
        name: 'MonitoringService');
  }

  /// Set an attribute (no-op in this simple implementation)
  void putAttribute(String name, String value) {
    developer.log('Attribute: $name = $value', name: 'MonitoringService');
  }

  /// Remove an attribute (no-op in this simple implementation)
  void removeAttribute(String name) {
    developer.log('Attribute removed: $name', name: 'MonitoringService');
  }
}
