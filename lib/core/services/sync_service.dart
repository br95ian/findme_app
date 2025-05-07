import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/local_item_repository.dart';
import '../../data/models/item_model.dart';
import '../../data/models/local/local_item_model.dart';
import '../utils/logger.dart';
import 'connectivity_service.dart';

class SyncService {
  final ItemRepository _itemRepository = ItemRepository();
  final LocalItemRepository _localItemRepository = LocalItemRepository();
  final ConnectivityService _connectivityService = ConnectivityService();
  final AppLogger _logger = AppLogger('SyncService');
  
  Timer? _syncTimer;
  bool _isSyncing = false;

  void initialize() {
    // Listen for connectivity changes
    _connectivityService.connectivityStream.listen((isOnline) {
      if (isOnline) {
        _logger.info('Device is online, starting sync');
        syncItems();
      } else {
        _logger.info('Device is offline, stopping sync timer');
        _stopSyncTimer();
      }
    });
    
    _connectivityService.isOnline().then((isOnline) {
      if (isOnline) {
        _startSyncTimer();
      }
    });
  }
  
  // Start periodic sync timer
  void _startSyncTimer() {
    _stopSyncTimer();
    
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      syncItems();
    });
    
    syncItems();
  }
  
  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  

  Future<void> syncItems() async {
    if (_isSyncing) {
      _logger.info('Sync already in progress, skipping');
      return;
    }
    
    _isSyncing = true;
    _logger.info('Starting sync process');
    
    try {
      // Check if we're online
      final isOnline = await _connectivityService.isOnline();
      
      if (!isOnline) {
        _logger.info('Device is offline, skipping sync');
        _isSyncing = false; 
        return;
      }
      
      // Get items that haven't been uploaded
      final notUploadedItems = await _localItemRepository.getNotUploadedItems();
      
      if (notUploadedItems.isEmpty) {
        _logger.info('No items to sync');
        _isSyncing = false;
        return;
      }
      
      _logger.info('Found ${notUploadedItems.length} items to sync');
      
      // Sync each item
      for (final localItem in notUploadedItems) {
        try {
          
          final imageFiles = localItem.imagePaths
              .map((path) => File(path))
              .toList();
          
          
          final imageUrls = await _itemRepository.uploadItemImages(imageFiles);
          
          // Create item model
          final item = ItemModel(
            id: localItem.id,
            userId: localItem.userId,
            userName: localItem.userName,
            userContact: localItem.userContact,
            title: localItem.title,
            description: localItem.description,
            category: localItem.category,
            type: localItem.type == LocalItemType.lost ? ItemType.lost : ItemType.found,
            imageUrls: imageUrls,
            location: GeoPoint(localItem.latitude, localItem.longitude),
            locationName: localItem.locationName,
            date: localItem.date,
            createdAt: localItem.createdAt,
            updatedAt: DateTime.now(),
          );
          
          
          await _itemRepository.createItem(item);
          
          // Mark as uploaded
          await _localItemRepository.markAsUploaded(localItem.id);
          
          _logger.info('Successfully synced item: ${localItem.id}');
        } catch (e) {
          _logger.error('Failed to sync item ${localItem.id}: $e');
        }
      }
      
      _logger.info('Sync completed');
    } catch (e) {
      _logger.error('Sync process failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  // Clean up resources
  void dispose() {
    _stopSyncTimer();
  }
}