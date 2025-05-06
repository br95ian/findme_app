import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  
  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    // Check initial connectivity status
    Connectivity().checkConnectivity().then(_updateStatus);
    
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // Consider online if any result is not none
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      notifyListeners();
    }
  }
}