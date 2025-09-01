/// Simple logger wrapper for the services
class Logger {
  final String name;

  Logger(this.name);

  void info(String message) {
    print('[$name] INFO: $message');
  }

  void debug(String message) {
    print('[$name] DEBUG: $message');
  }

  void warning(String message) {
    print('[$name] WARNING: $message');
  }

  void error(String message) {
    print('[$name] ERROR: $message');
  }
}