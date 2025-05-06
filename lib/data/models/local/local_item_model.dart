import 'package:hive/hive.dart';

part 'local_item_model.g.dart';

@HiveType(typeId: 1)
enum LocalItemType {
  @HiveField(0)
  lost,
  
  @HiveField(1)
  found
}

@HiveType(typeId: 0)
class LocalItemModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String userName;

  @HiveField(3)
  final String userContact;

  @HiveField(4)
  final String title;

  @HiveField(5)
  final String description;

  @HiveField(6)
  final String category;

  @HiveField(7)
  final LocalItemType type;

  @HiveField(8)
  final List<String> imagePaths;

  @HiveField(9)
  final double latitude;

  @HiveField(10)
  final double longitude;

  @HiveField(11)
  final String locationName;

  @HiveField(12)
  final DateTime date;

  @HiveField(13)
  final DateTime createdAt;

  @HiveField(14)
  final DateTime updatedAt;

  @HiveField(15)
  final bool isUploaded;

  LocalItemModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userContact,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.imagePaths,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.isUploaded = false,
  });

  // Create a copy with updated fields
  LocalItemModel copyWith({
    String? title,
    String? description,
    String? category,
    LocalItemType? type,
    List<String>? imagePaths,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? date,
    bool? isUploaded,
  }) {
    return LocalItemModel(
      id: id,
      userId: userId,
      userName: userName,
      userContact: userContact,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      imagePaths: imagePaths ?? this.imagePaths,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      date: date ?? this.date,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isUploaded: isUploaded ?? this.isUploaded,
    );
  }

  // Mark as uploaded
  LocalItemModel markAsUploaded() {
    return copyWith(isUploaded: true);
  }
}