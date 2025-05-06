import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerWidget extends StatelessWidget {
  final List<File> selectedImages;
  final Function(List<File>) onImagesChanged;
  final int maxImages;

  const ImagePickerWidget({
    Key? key,
    required this.selectedImages,
    required this.onImagesChanged,
    this.maxImages = 5,
  }) : super(key: key);

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    
    try {
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1000,
      );
      
      if (pickedFiles.isNotEmpty) {
        final newImages = pickedFiles.map((file) => File(file.path)).toList();
        
        // Limit number of images
        final currentLength = selectedImages.length;
        final newLength = currentLength + newImages.length;
        
        if (newLength > maxImages) {
          final imagesToAdd = newImages.sublist(0, maxImages - currentLength);
          onImagesChanged([...selectedImages, ...imagesToAdd]);
        } else {
          onImagesChanged([...selectedImages, ...newImages]);
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1000,
      );
      
      if (pickedFile != null) {
        final newImage = File(pickedFile.path);
        
        // Check if max images reached
        if (selectedImages.length < maxImages) {
          onImagesChanged([...selectedImages, newImage]);
        }
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  void _removeImage(int index) {
    final newImages = List<File>.from(selectedImages);
    newImages.removeAt(index);
    onImagesChanged(newImages);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: selectedImages.length >= maxImages 
                    ? null 
                    : _pickImages,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: selectedImages.length >= maxImages 
                    ? null 
                    : _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ),
          ],
        ),
        
        if (selectedImages.isNotEmpty) ...[
          const SizedBox(height: 16.0),
          
          // Selected images counter
          Text(
            '${selectedImages.length}/$maxImages images selected',
            style: const TextStyle(
              fontSize: 12.0,
              color: Colors.grey,
            ),
          ),
          
          const SizedBox(height: 8.0),
          
          // Image previews
          Container(
            height: 120.0,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 120.0,
                      height: 120.0,
                      margin: const EdgeInsets.only(right: 8.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        image: DecorationImage(
                          image: FileImage(selectedImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4.0,
                      right: 12.0,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ] else ...[
          const SizedBox(height: 16.0),
          Container(
            height: 120.0,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Text(
                'No images selected',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ],
    );
  }
}