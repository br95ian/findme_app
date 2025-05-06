import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final AppLogger _logger = AppLogger('ConnectivityService');

  // Stream controller for connectivity status
  final _connectivityController = StreamController<bool>.broadcast();

  // Stream of connectivity status (true = online, false = offline)
  Stream<bool> get connectivityStream => _connectivityController.stream;

  ConnectivityService() {
    // Initialize connectivity monitoring
    _initConnectivity();
    
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen(_updateConnectivityStatus);
  }

  // Initialize connectivity
  Future<void> _initConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(connectivityResult);
    } catch (e) {
      _logger.error('Failed to get connectivity: $e');
      _connectivityController.add(false); // Assume offline in case of error
    }
  }

  // Update connectivity status
  void _updateConnectivityStatus(List<ConnectivityResult> results) {
    // Consider online if any result is not none
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    
    _logger.info('Connectivity changed: ${results.map((r) => r.name).join(", ")} (online: $isOnline)');
    _connectivityController.add(isOnline);
  }

  // Check current connectivity
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  // Dispose resources
  void dispose() {
    _connectivityController.close();
  }
}