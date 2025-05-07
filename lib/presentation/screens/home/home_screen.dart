import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../../../core/services/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/item_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../data/models/item_model.dart';
import '../../widgets/item_card.dart';
import '../../../app/routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ItemModel> _lostItems = [];
  List<ItemModel> _foundItems = [];
  bool _isLoading = false;
  String? _searchQuery;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadItems();
    
    // Check if there are offline items to sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSyncOfflineItems();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  Future<void> requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API level 33+)
      if (await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestPermission() ??
          false) {
        log('Notification permission granted');
      } else {
        log('Notification permission denied');
      }
    }
  }
  
  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });
    
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    
    try {
      // Listen to lost items stream
      itemProvider.getItemsStream(type: ItemType.lost, isResolved: false)
          .listen((items) {
        if (mounted) {
          setState(() {
            _lostItems = items;
          });
        }
      });
      
      // Listen to found items stream
      itemProvider.getItemsStream(type: ItemType.found, isResolved: false)
          .listen((items) {
        if (mounted) {
          setState(() {
            _foundItems = items;
          });
        }
      });
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
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
  
  Future<void> _checkAndSyncOfflineItems() async {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    
    // If we're online, try to sync offline items
    if (connectivityProvider.isOnline) {
      try {
        await itemProvider.syncLocalItems();
        
        // Refresh items after sync
        _loadItems();
      } catch (e) {
        // Sync failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync offline items: ${e.toString()}')),
        );
      }
    }
  }
  
  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchQuery = null;
      });
      await _loadItems();
      return;
    }
    
    setState(() {
      _isLoading = true;
      _searchQuery = query;
    });
    
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    
    try {
      final results = await itemProvider.searchItems(query);
      
      // Filter results by tab
      if (mounted) {
        setState(() {
          _lostItems = results.where((item) => item.type == ItemType.lost).toList();
          _foundItems = results.where((item) => item.type == ItemType.found).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('FindMe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.profile);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, 
          unselectedLabelColor: Colors.white70, 
          indicatorColor: Colors.white, 
          indicatorWeight: 3.0, 
          tabs: const [
            Tab(text: 'Lost Items', icon: Icon(Icons.search)),
            Tab(text: 'Found Items', icon: Icon(Icons.check_circle)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Offline banner
          if (!connectivityProvider.isOnline)
            Container(
              color: Colors.orange,
              padding: const EdgeInsets.all(8.0),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'You\'re offline. Some features may not be available.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          
          // Search info if searching
          if (_searchQuery != null)
            Container(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.search),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text('Search results for: $_searchQuery'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _searchQuery = null;
                      });
                      _loadItems();
                    },
                  ),
                ],
              ),
            ),
          
          // Main content - Tab View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Lost items tab
                      _buildItemsList(_lostItems, ItemType.lost),
                      
                      // Found items tab
                      _buildItemsList(_foundItems, ItemType.found),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(
            context, 
            AppRoutes.itemForm,
            arguments: {
              'type': _tabController.index == 0 ? ItemType.lost : ItemType.found
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildItemsList(List<ItemModel> items, ItemType type) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == ItemType.lost ? Icons.search_off : Icons.find_in_page,
              size: 64.0,
              color: Colors.grey,
            ),
            const SizedBox(height: 16.0),
            Text(
              'No ${type == ItemType.lost ? 'lost' : 'found'} items yet',
              style: const TextStyle(
                fontSize: 18.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8.0),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text('Add ${type == ItemType.lost ? 'a lost' : 'a found'} item'),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.itemForm,
                  arguments: {'type': type},
                );
              },
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ItemCard(
            item: item,
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.itemDetails,
                arguments: {'itemId': item.id},
              );
            },
          );
        },
      ),
    );
  }
}

