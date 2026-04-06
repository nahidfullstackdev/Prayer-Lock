import 'package:logger/logger.dart';

/// Centralized logging utility for the application
///
/// Usage:
/// ```dart
/// AppLogger.debug('Debug message');
/// AppLogger.info('Info message');
/// AppLogger.warning('Warning message');
/// AppLogger.error('Error message', error, stackTrace);
/// ```
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Log debug message
  static void debug(String message) => _logger.d(message);

  /// Log info message
  static void info(String message) => _logger.i(message);

  /// Log warning message
  static void warning(String message) => _logger.w(message);

  /// Log error message with optional error object and stack trace
  static void error(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
