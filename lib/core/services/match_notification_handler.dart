import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';
import '../utils/logger.dart';

class MatchNotificationHandler {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final NotificationService _notificationService = NotificationService();
  final AppLogger _logger = AppLogger('MatchNotificationHandler');
  
  // Initialize the handler
  Future<void> initialize() async {
    // Request permission
    await _requestPermission();
    
    // Get FCM token
    final token = await _messaging.getToken();
    _logger.info('FCM Token: $token');
    
    // Configure message handling
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Check for initial message (app opened from terminated state)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleInitialMessage(initialMessage);
    }
  }
  
  // Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    _logger.info('User granted permission: ${settings.authorizationStatus}');
  }
  
  // Handle message received while app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    _logger.info('Received foreground message: ${message.messageId}');
    
    // Extract notification data
    final notification = message.notification;
    final data = message.data;
    
    if (notification != null) {
      // Show local notification
      _notificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: notification.title ?? 'New Match',
        body: notification.body ?? 'You have a new potential match',
        payload: data['itemId'],
      );
    }
  }
  
  // Handle message opened when app is in background
  void _handleMessageOpenedApp(RemoteMessage message) {
    _logger.info('Message opened app: ${message.messageId}');
    
    // Here you would navigate to the relevant screen based on the message data
    // This would be integrated with your navigation system
  }
  
  // Handle initial message (app opened from terminated state)
  void _handleInitialMessage(RemoteMessage message) {
    _logger.info('App opened from initial message: ${message.messageId}');
    
    // Here you would navigate to the relevant screen based on the message data
    // This would be integrated with your navigation system
  }
  
  // Subscribe to topic for receiving match notifications
  Future<void> subscribeToMatchNotifications(String userId) async {
    await _messaging.subscribeToTopic('matches_$userId');
    _logger.info('Subscribed to matches_$userId topic');
  }
  
  // Unsubscribe from match notifications
  Future<void> unsubscribeFromMatchNotifications(String userId) async {
    await _messaging.unsubscribeFromTopic('matches_$userId');
    _logger.info('Unsubscribed from matches_$userId topic');
  }
}