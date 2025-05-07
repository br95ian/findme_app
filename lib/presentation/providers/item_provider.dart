import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/local_item_repository.dart';
import '../../data/models/item_model.dart';
import '../../data/models/local/local_item_model.dart';
import '../../core/services/auth_service.dart';
import 'package:uuid/uuid.dart';

class ItemProvider extends ChangeNotifier {
  final ItemRepository _itemRepository = ItemRepository();
  final LocalItemRepository _localItemRepository = LocalItemRepository();
  final AuthService _authService = AuthService();
  
  List<ItemModel> _items = [];
  ItemModel? _selectedItem;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<ItemModel> get items => _items;
  ItemModel? get selectedItem => _selectedItem;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Stream of items
  Stream<List<ItemModel>> getItemsStream({
    ItemType? type,
    String? category,
    String? userId,
    bool? isResolved,
    double? lat,
    double? lng,
    double? radiusKm,
  }) {
    return _itemRepository.getItems(
      type: type,
      category: category,
      userId: userId,
      isResolved: isResolved,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
    );
  }
  
  // Load items
  Future<void> loadItems({
    ItemType? type,
    String? category,
    String? userId,
    bool? isResolved,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Listen to the stream once to get initial data
      final stream = _itemRepository.getItems(
        type: type,
        category: category,
        userId: userId,
        isResolved: isResolved,
      );
      
      final items = await stream.first;
      _items = items;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  // Get item by ID
  Future<void> getItemById(String id) async {
    _setLoading(true);
    _clearError();
    
    try {
      _selectedItem = await _itemRepository.getItemById(id);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  // Upload a new item
  Future<bool> uploadItem({
    required String title,
    required String description,
    required String category,
    required ItemType type,
    required List<File> images,
    required GeoPoint location,
    required String locationName,
    required DateTime date,
    String? phoneNumber, 
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final currentUser = await _authService.getUserProfile();
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Upload images
      final imageUrls = await _itemRepository.uploadItemImages(images);
      
      // Create item
      final item = ItemModel(
        userId: currentUser.id,
        userName: currentUser.name,
        userContact: currentUser.email,
        title: title,
        description: description,
        category: category,
        type: type,
        imageUrls: imageUrls,
        location: location,
        locationName: locationName,
        date: date,
        phoneNumber: phoneNumber
      );
      
      await _itemRepository.createItem(item);
      _selectedItem = item;
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Save item locally (for offline use)
  Future<bool> saveItemLocally({
    required String title,
    required String description,
    required String category,
    required LocalItemType type,
    required List<File> images,
    required double latitude,
    required double longitude,
    required String locationName,
    required DateTime date,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final currentUser = await _authService.getUserProfile();
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Save images locally
      final imagePaths = await _localItemRepository.saveImages(images);
      
      // Create local item
      final localItem = LocalItemModel(
        id: const Uuid().v4(),
        userId: currentUser.id,
        userName: currentUser.name,
        userContact: currentUser.email,
        title: title,
        description: description,
        category: category,
        type: type,
        imagePaths: imagePaths,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        date: date,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _localItemRepository.saveItem(localItem);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Sync local items with cloud
  Future<void> syncLocalItems() async {
    _setLoading(true);
    _clearError();
    
    try {
      // Get items that haven't been uploaded
      final localItems = await _localItemRepository.getNotUploadedItems();
      
      for (final localItem in localItems) {
        // Convert local image paths to File objects
        final imageFiles = localItem.imagePaths
            .map((path) => File(path))
            .toList();
        
        // Upload images
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
        
        // Save to cloud
        await _itemRepository.createItem(item);
        
        // Mark as uploaded
        await _localItemRepository.markAsUploaded(localItem.id);
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  // Update an item
  Future<bool> updateItem({
    required String id,
    String? title,
    String? description,
    String? category,
    ItemType? type,
    List<String>? imageUrls,
    GeoPoint? location,
    String? locationName,
    DateTime? date,
  }) async {
    _setLoading(true);
    _clearError();
    
    try {
      final currentItem = await _itemRepository.getItemById(id);
      
      if (currentItem == null) {
        throw Exception('Item not found');
      }
      
      final updatedItem = currentItem.copyWith(
        title: title,
        description: description,
        category: category,
        type: type,
        imageUrls: imageUrls,
        location: location,
        locationName: locationName,
        date: date,
      );
      
      await _itemRepository.updateItem(updatedItem);
      
      if (_selectedItem?.id == id) {
        _selectedItem = updatedItem;
      }
      
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Delete an item
  Future<bool> deleteItem(String id) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _itemRepository.deleteItem(id);
      
      if (_selectedItem?.id == id) {
        _selectedItem = null;
      }
      
      _items = _items.where((item) => item.id != id).toList();
      
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Mark an item as resolved
  Future<bool> markItemAsResolved(String itemId, String resolvedWithUserId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _itemRepository.markItemAsResolved(itemId, resolvedWithUserId);
      
      if (_selectedItem?.id == itemId) {
        final item = await _itemRepository.getItemById(itemId);
        _selectedItem = item;
      }
      
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  // Search items
  Future<List<ItemModel>> searchItems(String query) async {
    _setLoading(true);
    _clearError();
    
    try {
      final results = await _itemRepository.searchItems(query);
      return results;
    } catch (e) {
      _setError(e.toString());
      return [];
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