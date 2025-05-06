import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import '../models/local/local_item_model.dart';

class LocalItemRepository {
  static const String _boxName = 'items_box';
  
  // Open Hive box
  Future<Box<LocalItemModel>> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      // No need to register adapters here as they should be registered in main.dart
      return await Hive.openBox<LocalItemModel>(_boxName);
    }
    return Hive.box<LocalItemModel>(_boxName);
  }
  
  // Save images locally and return their paths
  Future<List<String>> saveImages(List<File> images) async {
    if (images.isEmpty) return [];
    
    List<String> imagePaths = [];
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/item_images');
    
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    
    for (final image in images) {
      final fileName = '${const Uuid().v4()}${path.extension(image.path)}';
      final savePath = '${imagesDir.path}/$fileName';
      
      // Compress the image before saving
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        image.path,
        savePath,
        quality: 70,
      );
      
      if (compressedFile != null) {
        imagePaths.add(compressedFile.path);
      }
    }
    
    return imagePaths;
  }
  
  // Save a new item locally
  Future<void> saveItem(LocalItemModel item) async {
    final box = await _openBox();
    await box.put(item.id, item);
  }
  
  // Get all saved items
  Future<List<LocalItemModel>> getAllItems() async {
    final box = await _openBox();
    return box.values.toList();
  }
  
  // Get items that haven't been uploaded yet
  Future<List<LocalItemModel>> getNotUploadedItems() async {
    final box = await _openBox();
    return box.values.where((item) => !item.isUploaded).toList();
  }
  
  // Get a specific item by ID
  Future<LocalItemModel?> getItemById(String id) async {
    final box = await _openBox();
    return box.get(id);
  }
  
  // Update an existing item
  Future<void> updateItem(LocalItemModel item) async {
    final box = await _openBox();
    await box.put(item.id, item);
  }
  
  // Mark an item as uploaded
  Future<void> markAsUploaded(String id) async {
    final box = await _openBox();
    final item = box.get(id);
    
    if (item != null) {
      final updatedItem = item.markAsUploaded();
      await box.put(id, updatedItem);
    }
  }
  
  // Delete an item and its images
  Future<void> deleteItem(String id) async {
    final box = await _openBox();
    final item = box.get(id);
    
    if (item != null) {
      // Delete associated images
      for (final imagePath in item.imagePaths) {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      // Delete the item
      await box.delete(id);
    }
  }
  
  // Clean up uploaded items (optional, for maintenance)
  Future<void> cleanUpUploadedItems() async {
    final box = await _openBox();
    final uploadedItems = box.values.where((item) => item.isUploaded).toList();
    
    for (final item in uploadedItems) {
      await deleteItem(item.id);
    }
  }
}