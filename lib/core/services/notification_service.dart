import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../app/routes.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    try {
      // Initialize settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationTap(response.payload ?? '', navigatorKey);
        },
      );
      
      
      await _createNotificationChannels();
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }
  
  Future<void> _createNotificationChannels() async {
    try {
      const AndroidNotificationChannel mainChannel = AndroidNotificationChannel(
        'findme_channel_id',
        'FindMe Notifications',
        description: 'Notifications from FindMe app',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );
      
      
      const AndroidNotificationChannel matchChannel = AndroidNotificationChannel(
        'findme_match_channel',
        'Match Notifications',
        description: 'Notifications about potential matches',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );
      
      
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(mainChannel);
        
        await androidImplementation.createNotificationChannel(matchChannel);
      } else {
      }
    } catch (e) {
      print('Error creating notification channels: $e');
    }
  }

  void _handleNotificationTap(String payload, GlobalKey<NavigatorState> navigatorKey) {
    
    if (payload.startsWith('match_')) {
     
      final parts = payload.split('_');
      if (parts.length >= 3) {
        final itemId = parts[1];
        final matchId = parts[2];
        
        
        navigatorKey.currentState?.pushNamed(
          AppRoutes.matchDetails,
          arguments: {'itemId': itemId, 'matchId': matchId},
        );
      }
    }
  }
  
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'findme_channel_id',
  }) async {
    try {
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == 'findme_match_channel' ? 'Match Notifications' : 'FindMe Notifications',
        channelDescription: 'Notifications from FindMe app',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
      );
      
      
      NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );
      
      
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
      
    } catch (e) {
      print('Error showing notification: $e');
    }
  }
  
  Future<void> showMatchNotification({
    required String itemTitle,
    required bool isLostItem,
    required String itemId,
    required String matchId,
  }) async {
    
    final title = isLostItem
        ? 'Potential match for your lost item'
        : 'Someone may have lost what you found';
    
    final body = 'There\'s a potential match for "$itemTitle"';
    
    // Create payload with both item IDs
    final payload = 'match_${itemId}_${matchId}';
    
    try {
      await showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        channelId: 'findme_match_channel',
        payload: payload,
      );
    } catch (e) {
      print('Error showing match notification: $e');
    }
  }
  
  
  
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
  
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
  
  Future<bool> requestNotificationPermissions() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestPermission();
        return granted ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}