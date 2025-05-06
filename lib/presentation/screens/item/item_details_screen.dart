import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/models/item_model.dart';
import '../../providers/item_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../../app/routes.dart'; // Make sure this import exists

class ItemDetailsScreen extends StatefulWidget {
  const ItemDetailsScreen({super.key});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  bool _isLoading = false;
  String? _error;
  ItemModel? _item;
  final int _currentImageIndex = 0;
  final Set<Marker> _markers = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadItem();
  }

  Future<void> _loadItem() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final itemId = args['itemId'] as String;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      await itemProvider.getItemById(itemId);
      
      if (mounted) {
        setState(() {
          _item = itemProvider.selectedItem;
          _isLoading = false;
          
          if (_item != null) {
            // Add marker for the item's location
            _markers.add(
              Marker(
                markerId: MarkerId(_item!.id),
                position: LatLng(
                  _item!.location.latitude,
                  _item!.location.longitude,
                ),
                infoWindow: InfoWindow(
                  title: _item!.locationName,
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsResolved() async {
    if (_item == null) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to perform this action')),
      );
      return;
    }
    
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Resolved'),
        content: Text(
          'Are you sure you want to mark this ${_item!.type == ItemType.lost ? 'lost' : 'found'} '
          'item as resolved?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Using currentUser.uid from auth provider instead of userId
      final uid = authProvider.currentUser?.uid; // Fixed: using currentUser?.uid instead of userId
      if (uid == null) {
        throw Exception('User ID not available');
      }
      
      final success = await itemProvider.markItemAsResolved(_item!.id, uid);
      
      if (success && mounted) {
        // Reload the item to show updated status
        await _loadItem();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item marked as resolved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteItem() async {
    // Confirm dialog
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
    
    if (confirm != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      final success = await itemProvider.deleteItem(_item!.id);
      
      if (success && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Item Details'),
        ),
        body: Center(
          child: Text('Error: $_error'),
        ),
      );
    }

    if (_item == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Item Details'),
        ),
        body: const Center(
          child: Text('Item not found'),
        ),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context);
    final isCurrentUserItem = _item!.userId == authProvider.currentUser?.uid; // Fixed: using currentUser?.uid instead of userId

    return Scaffold(
      appBar: AppBar(
        title: Text(_item!.title),
        actions: [
          if (isCurrentUserItem)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.itemForm, // Use AppRoutes class instead of Routes
                    arguments: {'item': _item},
                  );
                } else if (value == 'delete') {
                  _deleteItem();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image carousel
            if (_item!.imageUrls.isNotEmpty)
              SizedBox(
                height: 250,
                child: PageView.builder(
                  itemCount: _item!.imageUrls.length,
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: _item!.imageUrls[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    );
                  },
                  onPageChanged: (index) {
                    // Update current image index if needed
                  },
                ),
              ),
            
            // Item details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        backgroundColor: _item!.type == ItemType.lost
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        label: Text(
                          _item!.type == ItemType.lost ? 'Lost' : 'Found',
                          style: TextStyle(
                            color: _item!.type == ItemType.lost
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                      Text(
                        'Category: ${_item!.category}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _item!.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date: ${DateFormat('MMM dd, yyyy').format(_item!.date)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Description:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(_item!.description),
                  const SizedBox(height: 16),
                  Text(
                    'Location:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(_item!.locationName),
                  const SizedBox(height: 16),
                  
                  // Map
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            _item!.location.latitude,
                            _item!.location.longitude,
                          ),
                          zoom: 15,
                        ),
                        markers: _markers,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Contact info
                  Text(
                    'Contact Information:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Name: ${_item!.userName}'),
                  Text('Contact: ${_item!.userContact}'),
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  if (!_item!.isResolved)
                    CustomButton(
                      text: 'Mark as Resolved',
                      onPressed: _markAsResolved,
                      color: Theme.of(context).primaryColor,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}