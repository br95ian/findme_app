import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum ItemType { lost, found }

class ItemModel {
  final String id;
  final String userId;
  final String userName;
  final String userContact;
  final String title;
  final String description;
  final String category;
  final ItemType type;
  final List<String> imageUrls;
  final GeoPoint location;
  final String locationName;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isResolved;
  final String? resolvedWithUserId;
  final DateTime? resolvedAt;
  final String? phoneNumber;

  ItemModel({
    String? id,
    required this.userId,
    required this.userName,
    required this.userContact,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.imageUrls,
    required this.location,
    required this.locationName,
    required this.date,
    this.phoneNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isResolved = false,
    this.resolvedWithUserId,
    this.resolvedAt,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userContact': userContact,
      'title': title,
      'phoneNumber': phoneNumber,
      'description': description,
      'category': category,
      'type': type.name,
      'imageUrls': imageUrls,
      'location': location,
      'locationName': locationName,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isResolved': isResolved,
      'resolvedWithUserId': resolvedWithUserId,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  // Create from Map
  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'],
      userId: map['userId'],
      userName: map['userName'],
      userContact: map['userContact'],
      title: map['title'],
      description: map['description'],
      category: map['category'],
      type: ItemType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ItemType.lost,
      ),
      imageUrls: List<String>.from(map['imageUrls']),
      location: map['location'],
      locationName: map['locationName'],
      phoneNumber: map['phoneNumber'],
      date: (map['date'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isResolved: map['isResolved'] ?? false,
      resolvedWithUserId: map['resolvedWithUserId'],
      resolvedAt: map['resolvedAt'] != null 
          ? (map['resolvedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  // Create copy
  ItemModel copyWith({
    String? title,
    String? description,
    String? category,
    ItemType? type,
    List<String>? imageUrls,
    GeoPoint? location,
    String? locationName,
    DateTime? date,
    bool? isResolved,
    String? resolvedWithUserId,
    DateTime? resolvedAt,
  }) {
    return ItemModel(
      id: id,
      userId: userId,
      userName: userName,
      userContact: userContact,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      imageUrls: imageUrls ?? this.imageUrls,
      location: location ?? this.location,
      locationName: locationName ?? this.locationName,
      date: date ?? this.date,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isResolved: isResolved ?? this.isResolved,
      resolvedWithUserId: resolvedWithUserId ?? this.resolvedWithUserId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  // Mark as resolved
  ItemModel markAsResolved(String resolvedWithUserId) {
    return copyWith(
      isResolved: true,
      resolvedWithUserId: resolvedWithUserId,
      resolvedAt: DateTime.now(),
    );
  }
}