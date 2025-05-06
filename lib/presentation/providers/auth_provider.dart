import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  UserModel? get user => _user;
  UserModel? get currentUser => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  
  // Constructor - Check if user is already logged in
  AuthProvider() {
    _checkCurrentUser();
  }
  
  // Check current user
  Future<void> _checkCurrentUser() async {
    _setLoading(true);
    try {
      _user = await _authService.getUserProfile();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  // Sign in
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();
    
    try {
      _user = await _authService.loginWithEmailAndPassword(email, password);
      return true;
    } catch (e) {
      _setError("Invalid email or password. Please try again.");
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Register
  Future<bool> register(String name, String email, String password) async {
    _setLoading(true);
    _clearError();
    
    try {
      _user = await _authService.registerWithEmailAndPassword(name, email, password);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();
    
    try {
      await _authService.signOut();
      _user = null;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  // Update profile
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      _user = await _authService.updateUserProfile(
        name: name,
        phone: phone,
        photoUrl: photoUrl,
      );
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  void _clearError() {
    _error = null;
    notifyListeners();
  }
}