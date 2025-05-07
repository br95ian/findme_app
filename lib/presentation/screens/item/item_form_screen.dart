import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/services/match_service.dart';
import '../../../data/models/item_model.dart';
import '../../../data/models/local/local_item_model.dart';
import '../../providers/item_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../../app/routes.dart';

class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({Key? key}) : super(key: key);

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _category = 'Electronics';
  ItemType _itemType = ItemType.lost;
  DateTime _date = DateTime.now();
  List<File> _images = [];
  LatLng? _selectedLocation;
  bool _isLoading = false;
  bool _isInitialized = false;
  ItemModel? _existingItem;
  Set<Marker> _markers = {};
  
  // Category options
  final List<String> _categories = [
    'Electronics',
    'Clothing',
    'Accessories',
    'Documents',
    'Keys',
    'Wallet',
    'Bag',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (_isInitialized) return;
    
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null) {
      if (args.containsKey('type')) {
        setState(() {
          _itemType = args['type'] as ItemType;
        });
      }
      
      if (args.containsKey('item')) {
        _existingItem = args['item'] as ItemModel;
        _loadExistingItemData();
      }
    }
    
    _getCurrentLocation();
    _isInitialized = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _loadExistingItemData() {
    if (_existingItem == null) return;
    
    setState(() {
      _titleController.text = _existingItem!.title;
      _descriptionController.text = _existingItem!.description;
      _category = _existingItem!.category;
      _itemType = _existingItem!.type;
      _date = _existingItem!.date;
      _locationNameController.text = _existingItem!.locationName;
      _phoneController.text = _existingItem!.phoneNumber ?? '';
      _selectedLocation = LatLng(
        _existingItem!.location.latitude,
        _existingItem!.location.longitude,
      );
      
      // Update marker
      _updateMarker();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location permission is granted
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission permanently denied, we cannot request it'),
          ),
        );
        return;
      }
      
      // Get current position if we don't have a selected location yet
      if (_selectedLocation == null) {
        final position = await Geolocator.getCurrentPosition();
        
        if (mounted) {
          setState(() {
            _selectedLocation = LatLng(position.latitude, position.longitude);
            _updateMarker();
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get current location: $e')),
      );
    }
  }

  void _updateMarker() {
    if (_selectedLocation == null) return;
    
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation!,
          infoWindow: InfoWindow(
            title: _locationNameController.text.isNotEmpty 
                ? _locationNameController.text 
                : 'Selected Location',
          ),
        ),
      };
    });
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    
    try {
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1000,
      );
      
      if (pickedFiles.isNotEmpty && mounted) {
        setState(() {
          _images.addAll(pickedFiles.map((file) => File(file.path)).toList());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e')),
      );
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
      
      if (pickedFile != null && mounted) {
        setState(() {
          _images.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take picture: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final initialDate = _date;
    final lastDate = DateTime.now();
    final firstDate = lastDate.subtract(const Duration(days: 365));
    
    final newDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(lastDate) ? initialDate : lastDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    
    if (newDate != null && mounted) {
      setState(() {
        _date = newDate;
      });
    }
  }

  Future<String> _getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return "${place.name ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}".trim();
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
    }

    return "Selected Location";
  }

  Future<void> _selectLocation() async {
    LatLng? dialogSelectedLocation = _selectedLocation;
    Set<Marker> dialogMarkers = {
      if (dialogSelectedLocation != null)
        Marker(
          markerId: const MarkerId('selected_location'),
          position: dialogSelectedLocation,
          infoWindow: const InfoWindow(title: 'Selected Location'),
        ),
    };
    GoogleMapController? mapController;
    final result = await showDialog<LatLng>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            

            return AlertDialog(
              title: const Text('Select Location'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: dialogSelectedLocation ?? const LatLng(0, 0),
                          zoom: dialogSelectedLocation != null ? 15 : 2,
                        ),
                        onMapCreated: (controller) => mapController = controller,
                        onTap: (latLng) {
                          dialogSelectedLocation = latLng;
                          setDialogState(() {
                            dialogMarkers = {
                              Marker(
                                markerId: const MarkerId('selected_location'),
                                position: latLng,
                                infoWindow: const InfoWindow(title: 'Selected Location'),
                              ),
                            };
                          });
                          mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(latLng, 15),
                          );
                        },
                        markers: dialogMarkers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.my_location),
                          label: const Text("My Location"),
                          onPressed: () async {
                            try {
                              final position = await Geolocator.getCurrentPosition();
                              final myLocation = LatLng(position.latitude, position.longitude);
                              dialogSelectedLocation = myLocation;
                              setDialogState(() {
                                dialogMarkers = {
                                  Marker(
                                    markerId: const MarkerId('selected_location'),
                                    position: myLocation,
                                    infoWindow: const InfoWindow(title: 'Selected Location'),
                                  ),
                                };
                              });

                              mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(myLocation, 15),
                              );
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to get location: $e')),
                              );
                            }
                          },
                        ),
                        ElevatedButton(
                          onPressed: dialogSelectedLocation != null
                              ? () => Navigator.pop(context, dialogSelectedLocation)
                              : null,
                          child: const Text('Select'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      final address = await _getAddressFromLatLng(result);
      setState(() {
        _selectedLocation = result;
        _locationNameController.text = address;
        _updateMarker();
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }
    
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
    
    try {
      bool success;
      
      // Check if we're editing an existing item
      if (_existingItem != null) {
        success = await itemProvider.updateItem(
          id: _existingItem!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          category: _category,
          type: _itemType,
          location: GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
          locationName: _locationNameController.text,
          date: _date,
        );
      } else {
        // Check if we're online
        if (connectivityProvider.isOnline) {
          // Upload directly
          success = await itemProvider.uploadItem(
            title: _titleController.text,
            description: _descriptionController.text,
            category: _category,
            type: _itemType,
            images: _images,
            location: GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
            locationName: _locationNameController.text,
            date: _date,
            phoneNumber: _phoneController.text,
          );
        } else {
          // Save locally
          success = await itemProvider.saveItemLocally(
            title: _titleController.text,
            description: _descriptionController.text,
            category: _category,
            type: _itemType == ItemType.lost ? LocalItemType.lost : LocalItemType.found,
            images: _images,
            latitude: _selectedLocation!.latitude,
            longitude: _selectedLocation!.longitude,
            locationName: _locationNameController.text,
            date: _date,
          );
          
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Item saved locally and will be uploaded when you\'re back online'),
              ),
            );
          }
        }
      }
      
      if (success && mounted) {
        final newItem = itemProvider.selectedItem; 
        if (newItem != null) {
          final matchService = MatchService();
          await matchService.findPotentialMatches(newItem);
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save item: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingItem != null ? 'Edit Item' : 'Add Item'),
        actions: [
          if (_existingItem != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Item'),
                    content: const Text('Are you sure you want to delete this item?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  setState(() {
                    _isLoading = true;
                  });
                  
                  try {
                    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
                    final success = await itemProvider.deleteItem(_existingItem!.id);
                    
                    if (success && mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete item: $e')),
                      );
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Item type toggle
                    Row(
                      children: [
                        const Text('Item Type:'),
                        const SizedBox(width: 16),
                        SegmentedButton<ItemType>(
                          segments: const [
                            ButtonSegment<ItemType>(
                              value: ItemType.lost,
                              label: Text('Lost'),
                              icon: Icon(Icons.search),
                            ),
                            ButtonSegment<ItemType>(
                              value: ItemType.found,
                              label: Text('Found'),
                              icon: Icon(Icons.check_circle),
                            ),
                          ],
                          selected: {_itemType},
                          onSelectionChanged: (Set<ItemType> newSelection) {
                            setState(() {
                              _itemType = newSelection.first;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Title
                    CustomTextField(
                      controller: _titleController,
                      labelText: 'Title',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _category = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    CustomTextField(
                      controller: _descriptionController,
                      labelText: 'Description',
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Date picker
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('MMM dd, yyyy').format(_date)),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Phone number field
                    CustomTextField(
                      controller: _phoneController,
                      labelText: 'Contact Phone Number (optional)',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone),
                      hintText: 'Enter your phone number for contact',
                    ),
                    const SizedBox(height: 16),
                    
                    // Location
                    CustomTextField(
                      controller: _locationNameController,
                      labelText: 'Location Name',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a location name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _selectLocation,
                      icon: const Icon(Icons.location_on),
                      label: const Text('Select on Map'),
                    ),
                    if (_selectedLocation != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _selectedLocation!,
                              zoom: 15,
                            ),
                            markers: _markers,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            myLocationButtonEnabled: false,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    // Images
                    const Text(
                      'Images',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _takePicture,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_images.isNotEmpty) ...[
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _images[index],
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Submit button
                    CustomButton(
                      text: _existingItem != null ? 'Update' : 'Submit',
                      onPressed: _submitForm,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}