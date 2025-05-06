import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/item_model.dart';
import 'dart:math' as math;
import 'notification_service.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  
  // Find potential matches for a newly added item
  Future<List<ItemModel>> findPotentialMatches(ItemModel newItem) async {

    final oppositeType = newItem.type == ItemType.lost
        ? ItemType.found
        : ItemType.lost;
    
    // Query items of the opposite type that are not resolved
    final QuerySnapshot querySnapshot = await _firestore
        .collection('items')
        .where('type', isEqualTo: oppositeType.name)
        .where('isResolved', isEqualTo: false)
        .where('category', isEqualTo: newItem.category)
        .get();
    
    // Convert to item models
    final items = querySnapshot.docs
        .map((doc) => ItemModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
    
    // Filter items by proximity (if location is available)
    final nearbyItems = items.where((item) {
      // Calculate distance between items
      final distance = _calculateDistance(
        newItem.location.latitude,
        newItem.location.longitude,
        item.location.latitude,
        item.location.longitude,
      );
      
      // Consider items within 1km as potential matches
      return distance <= 1.0;
    }).toList();
    
    // Send notifications for matches
    for (final item in nearbyItems) {
      // If the item was reported by a different user
      if (item.userId != newItem.userId) {
        // Send notification to the user who reported the item
        await _notificationService.showMatchNotification(
          itemTitle: item.title,
          isLostItem: item.type == ItemType.lost,
        );
      }
    }
    
    return nearbyItems;
  }
  
  // Helper method to calculate distance using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - 
        math.cos(((lat2 - lat1) * p) / 2) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    
    return 12742 * math.asin(math.sqrt(a)); // Distance in km
  }
}