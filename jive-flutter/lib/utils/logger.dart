import 'package:flutter/foundation.dart';

/// Simple logger wrapper for the services
class Logger {
  final String name;

  Logger(this.name);

  void info(String message) {
    debugPrint('[$name] INFO: $message');
  }

  void debug(String message) {
    debugPrint('[$name] DEBUG: $message');
  }

  void warning(String message) {
    debugPrint('[$name] WARNING: $message');
  }

  void error(String message) {
    debugPrint('[$name] ERROR: $message');
  }
}
