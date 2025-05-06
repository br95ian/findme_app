class AppLogger {
  final String _tag;
  
  AppLogger(this._tag);
  
  void info(String message) {
    _log('INFO', message);
  }
  
  void error(String message) {
    _log('ERROR', message);
  }
  
  void warning(String message) {
    _log('WARNING', message);
  }
  
  void debug(String message) {
    _log('DEBUG', message);
  }
  
  void _log(String level, String message) {
    final timestamp = DateTime.now().toString();
    print('[$timestamp] [$level] [$_tag] - $message');
  }
}