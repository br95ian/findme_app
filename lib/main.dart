import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'data/models/local/local_item_model.dart';
import 'firebase_options.dart';
import 'app/app.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Future<void> main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive before registering adapters
  await Hive.initFlutter();
  
  // Register Hive adapters - only if not already registered
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(LocalItemModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(LocalItemTypeAdapter());
  }
  
  // Initialize Firebase
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    Firebase.app(); // Get the existing instance
  }
  
  // Initialize notifications
  final notificationService = NotificationService();
  await notificationService.initialize(navigatorKey);
  await notificationService.requestNotificationPermissions();
  
  // Initialize sync service
  final syncService = SyncService();
  syncService.initialize();
  
  // Run the app
  runApp( FindMeApp(navigatorKey: navigatorKey,)); 
}