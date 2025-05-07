import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/item_model.dart';
import '../../../core/utils/logger.dart';
import 'dart:math' as math;


class MatchDetailsScreen extends StatefulWidget {
  const MatchDetailsScreen({Key? key}) : super(key: key);

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppLogger _logger = AppLogger('MatchDetailsScreen');
  
  bool _isLoading = true;
  ItemModel? _lostItem;
  ItemModel? _foundItem;
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMatchDetails();
  }
  
  Future<void> _loadMatchDetails() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final itemId = args['itemId'] as String;
      final matchId = args['matchId'] as String;
      
      _logger.info('Loading match details for item $itemId and match $matchId');
      
      // Load both items
      final itemDoc = await _firestore.collection('items').doc(itemId).get();
      final matchDoc = await _firestore.collection('items').doc(matchId).get();
      
      if (!itemDoc.exists || !matchDoc.exists) {
        throw Exception('One or both items not found');
      }
      
      final itemData = itemDoc.data() as Map<String, dynamic>;
      final matchData = matchDoc.data() as Map<String, dynamic>;
      
      final item = ItemModel.fromMap(itemData);
      final match = ItemModel.fromMap(matchData);
      
      // Determine which is the lost and which is the found item
      if (item.type == ItemType.lost) {
        _lostItem = item;
        _foundItem = match;
      } else {
        _lostItem = match;
        _foundItem = item;
      }
      
      _setupMarkers();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.error('Error loading match details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load match details: $e')),
        );
        Navigator.pop(context);
      }
    }
  }
  
  void _setupMarkers() {
    if (_lostItem == null || _foundItem == null) return;
    
    // Create markers for lost and found locations
    final lostMarker = Marker(
      markerId: const MarkerId('lost_location'),
      position: LatLng(
        _lostItem!.location.latitude,
        _lostItem!.location.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: 'Lost: ${_lostItem!.title}',
        snippet: _lostItem!.locationName,
      ),
    );
    
    final foundMarker = Marker(
      markerId: const MarkerId('found_location'),
      position: LatLng(
        _foundItem!.location.latitude,
        _foundItem!.location.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: 'Found: ${_foundItem!.title}',
        snippet: _foundItem!.locationName,
      ),
    );
    
    setState(() {
      _markers = {lostMarker, foundMarker};
    });
  }
  
  void _fitMapToBounds() {
    if (_mapController == null || _lostItem == null || _foundItem == null) return;
    
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_lostItem!.location.latitude, _foundItem!.location.latitude),
        math.min(_lostItem!.location.longitude, _foundItem!.location.longitude),
      ),
      northeast: LatLng(
        math.max(_lostItem!.location.latitude, _foundItem!.location.latitude),
        math.max(_lostItem!.location.longitude, _foundItem!.location.longitude),
      ),
    );
    
    // Add some padding
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Map view
                Expanded(
                  flex: 3,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        (_lostItem!.location.latitude + _foundItem!.location.latitude) / 2,
                        (_lostItem!.location.longitude + _foundItem!.location.longitude) / 2,
                      ),
                      zoom: 12,
                    ),
                    markers: _markers,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _fitMapToBounds();
                    },
                    mapType: MapType.normal,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    compassEnabled: true,
                  ),
                ),
                
                // Match info
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Potential Match Found!',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Lost item details card
                          Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.search, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Lost Item: ${_lostItem!.title}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Reported by: ${_lostItem!.userName}'),
                                  const SizedBox(height: 4),
                                  Text('Location: ${_lostItem!.locationName}'),
                                  const SizedBox(height: 8),
                                  Text('Contact Email: ${_lostItem!.userContact}'),
                                  if (_lostItem!.phoneNumber != null && _lostItem!.phoneNumber!.isNotEmpty)
                                    Text('Contact Phone: ${_lostItem!.phoneNumber}'),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Found item details card
                          Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Found Item: ${_foundItem!.title}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Reported by: ${_foundItem!.userName}'),
                                  const SizedBox(height: 4),
                                  Text('Location: ${_foundItem!.locationName}'),
                                  const SizedBox(height: 8),
                                  Text('Contact Email: ${_foundItem!.userContact}'),
                                  if (_foundItem!.phoneNumber != null && _foundItem!.phoneNumber!.isNotEmpty)
                                    Text('Contact Phone: ${_foundItem!.phoneNumber}'),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Mark as resolved button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Mark as Resolved'),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirm Resolution'),
                                    content: const Text(
                                      'Are you sure you want to mark this match as resolved? '
                                      'This means the item has been returned to its owner.'
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
                                
                                if (confirm == true) {
                                  // Handle resolution logic here
                                  // This would typically call a method in your ItemProvider
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Items marked as resolved')),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}