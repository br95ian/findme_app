import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../app/routes.dart';

class NotificationHandler {
  // Singleton pattern
  static final NotificationHandler _instance = NotificationHandler._internal();
  factory NotificationHandler() => _instance;
  NotificationHandler._internal();

  // Global navigator key to access navigation context from anywhere
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  // Initialize the notification handler
  void initialize(FlutterLocalNotificationsPlugin notificationsPlugin) {
    print("Initializing notification handler");
    
    // Set up notification tap listener
    notificationsPlugin.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
    
    print("Notification handler initialized");
  }
  
  // Handle when a notification is tapped
  void _handleNotificationTap(NotificationResponse notificationResponse) {
    print("Notification tapped: ${notificationResponse.payload}");
    
    if (notificationResponse.payload == null) {
      print("Error: Notification payload is null");
      return;
    }
    
    try {
      // Check if the payload is for a match notification
      if (notificationResponse.payload!.startsWith('match_')) {
        // Extract match data from the payload
        final payloadData = notificationResponse.payload!.split('_');
        if (payloadData.length >= 3) {
          final lostItemId = payloadData[1];
          final foundItemId = payloadData[2];
          
          print("Handling match notification: Lost item ID: $lostItemId, Found item ID: $foundItemId");
          
          // Navigate to match details screen with the extracted IDs
          _navigateToMatchDetails(lostItemId, foundItemId);
        } else {
          print("Error: Invalid match notification payload format");
        }
      } 
    } catch (e) {
      print("Error handling notification tap: $e");
    }
  }
  
  // Helper method to navigate to match details screen
  void _navigateToMatchDetails(String lostItemId, String foundItemId) {
    if (navigatorKey.currentState != null) {
      // Prepare match data to pass to the screen
      final Map<String, dynamic> matchData = {
        'lostItemId': lostItemId,
        'foundItemId': foundItemId,
      };
      
      // Navigate to the match details screen
      navigatorKey.currentState!.pushNamed(
        AppRoutes.matchDetails,
        arguments: {'matchData': matchData},
      );
      
      print("Navigated to match details screen");
    } else {
      print("Error: Navigator is not available");
    }
  }
    
  
  // Navigate to item resolution screen
  void _navigateToItemResolution(Map<String, dynamic> payload) {
    if (navigatorKey.currentState != null) {
      final String? itemId = payload['itemId'];
      
      if (itemId != null) {
        navigatorKey.currentState!.pushNamed(
          AppRoutes.itemDetails,
          arguments: {'itemId': itemId},
        );
      } else {
        _navigateToHome();
      }
    }
  }
    
  
  // Navigate to home screen (fallback)
  void _navigateToHome() {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
    }
  }
  
  // Update NotificationService to use this payload format for matches
  String createMatchPayload(String lostItemId, String foundItemId) {
    return 'match_${lostItemId}_${foundItemId}';
  }
}