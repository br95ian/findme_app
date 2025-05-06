import 'dart:io';
import 'dart:math' as math; // Add this import for math functions
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../../core/services/auth_service.dart';
import '../models/item_model.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class ItemRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Get items collection reference
  CollectionReference get _itemsCollection => _firestore.collection('items');

  // Get item stream
  Stream<List<ItemModel>> getItems({
    ItemType? type,
    String? category,
    String? userId,
    bool? isResolved,
    double? lat,
    double? lng,
    double? radiusKm,
  }) {
    Query query = _itemsCollection;

    // Apply filters if provided
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    if (isResolved != null) {
      query = query.where('isResolved', isEqualTo: isResolved);
    }

    // Order by most recent
    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map((snapshot) {
      List<ItemModel> items = snapshot.docs
          .map((doc) => ItemModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // If location filtering is requested
      if (lat != null && lng != null && radiusKm != null) {
        // Filter items within the radius
        items = items.where((item) {
          final itemLat = item.location.latitude;
          final itemLng = item.location.longitude;
          
          // Calculate distance (using Haversine formula)
          final distance = _calculateDistance(lat, lng, itemLat, itemLng);
          
          // Convert to km and check if within radius
          return distance <= radiusKm;
        }).toList();
      }

      return items;
    });
  }

  // Helper method to calculate distance using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - 
        math.cos(((lat2 - lat1) * p) / 2) / 2 + 
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    
    // Return distance in km (6371 is Earth's radius in km)
    return 12742 * math.asin(math.sqrt(a)); // 2 * R * asin(sqrt(a))
  }

  // Get a single item by ID
  Future<ItemModel?> getItemById(String id) async {
    final doc = await _itemsCollection.doc(id).get();
    
    if (!doc.exists) {
      return null;
    }
    
    return ItemModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  // Upload item images
  final cloudinary = CloudinaryPublic('dcmsie5au', 'findme', cache: false);

  Future<List<String>> uploadItemImages(List<File> images) async {
    List<String> imageUrls = [];

    for (final image in images) {
      try {
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(image.path, resourceType: CloudinaryResourceType.Image),
        );
        imageUrls.add(response.secureUrl);
      } catch (e) {
        throw Exception('Failed to upload image to Cloudinary: $e');
      }
    }

    return imageUrls;
  }

  // Create a new item
  Future<ItemModel> createItem(ItemModel item) async {
    final doc = _itemsCollection.doc(item.id);
    await doc.set(item.toMap());
    return item;
  }

  // Update an existing item
  Future<void> updateItem(ItemModel item) async {
    await _itemsCollection.doc(item.id).update(item.toMap());
  }

  // Delete an item
  Future<void> deleteItem(String id) async {
    await _itemsCollection.doc(id).delete();
  }

  // Mark an item as resolved
  Future<void> markItemAsResolved(String itemId, String resolvedWithUserId) async {
    final item = await getItemById(itemId);
    
    if (item == null) {
      throw Exception('Item not found');
    }
    
    final resolvedItem = item.markAsResolved(resolvedWithUserId);
    await updateItem(resolvedItem);
  }

  // Search items
  Future<List<ItemModel>> searchItems(String query) async {
    final titleResults = await _itemsCollection
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
        
    final descResults = await _itemsCollection
        .where('description', isGreaterThanOrEqualTo: query)
        .where('description', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
        
    // Combine results and remove duplicates
    final combinedResults = [
      ...titleResults.docs.map((e) => ItemModel.fromMap(e.data() as Map<String, dynamic>)),
      ...descResults.docs.map((e) => ItemModel.fromMap(e.data() as Map<String, dynamic>)),
    ];
    
    // Remove duplicates by ID
    final uniqueItems = <String, ItemModel>{};
    for (final item in combinedResults) {
      uniqueItems[item.id] = item;
    }
    
    return uniqueItems.values.toList();
  }
}