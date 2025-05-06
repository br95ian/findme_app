import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/item_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../../data/models/item_model.dart';
import '../../../app/routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  late TabController _tabController;
  File? _profileImage;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploading = false;
  List<ItemModel> _myItems = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _loadUserItems();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user != null) {
      setState(() {
        _nameController.text = user.name;
        _phoneController.text = user.phone ?? '';
      });
    }
  }
  
  Future<void> _loadUserItems() async {
    setState(() {
      _isLoading = true;
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      try {
        final lostItemsStream = itemProvider.getItemsStream(
          userId: authProvider.user!.id,
          type: ItemType.lost,
        );
        
        final foundItemsStream = itemProvider.getItemsStream(
          userId: authProvider.user!.id,
          type: ItemType.found,
        );
        
        // Get initial data
        final lostItems = await lostItemsStream.first;
        final foundItems = await foundItemsStream.first;
        
        if (mounted) {
          setState(() {
            _myItems = [...lostItems, ...foundItems];
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load items: ${e.toString()}')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 500,
      );
      
      if (pickedFile != null && mounted) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }
  
  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;
      
      if (userId == null) return null;
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');
      
      final uploadTask = await storageRef.putFile(_profileImage!);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Upload profile image if selected
      String? photoUrl;
      if (_profileImage != null) {
        photoUrl = await _uploadProfileImage();
      }
      
      // Update profile
      final success = await authProvider.updateProfile(
        name: _nameController.text,
        phone: _phoneController.text,
        photoUrl: photoUrl,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        
        setState(() {
          _isEditing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
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
  
  Future<void> _signOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      await authProvider.signOut();
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign out: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: const Center(
          child: Text('Please sign in to view your profile'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'My Items'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Profile Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: _isEditing ? _buildEditProfileForm() : _buildProfileInfo(user),
          ),
          
          // My Items Tab
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildMyItemsList(),
        ],
      ),
    );
  }
  
  Widget _buildProfileInfo(user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Profile Image
        CircleAvatar(
          radius: 60.0,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: user.photoUrl != null
              ? NetworkImage(user.photoUrl!)
              : null,
          child: user.photoUrl == null
              ? const Icon(Icons.person, size: 60.0, color: Colors.grey)
              : null,
        ),
        
        const SizedBox(height: 24.0),
        
        // Name
        Text(
          user.name,
          style: const TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 8.0),
        
        // Email
        Text(
          user.email,
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.grey[600],
          ),
        ),
        
        if (user.phone != null && user.phone!.isNotEmpty) ...[
          const SizedBox(height: 8.0),
          
          // Phone
          Text(
            user.phone!,
            style: TextStyle(
              fontSize: 16.0,
              color: Colors.grey[600],
            ),
          ),
        ],
        
        const SizedBox(height: 32.0),
        
        // Stats Card
        Card(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activity Stats',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16.0),
                
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      count: _myItems.where((item) => item.type == ItemType.lost).length,
                      label: 'Lost Items',
                      color: Colors.orange,
                    ),
                    _buildStatItem(
                      count: _myItems.where((item) => item.type == ItemType.found).length,
                      label: 'Found Items',
                      color: Colors.green,
                    ),
                    _buildStatItem(
                      count: _myItems.where((item) => item.isResolved).length,
                      label: 'Resolved',
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24.0),
        
        // Account Info
        Card(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Information',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16.0),
                
                // Account Info
                _buildInfoRow('Email', user.email),
                const SizedBox(height: 8.0),
                _buildInfoRow('Member Since', 
                    '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatItem({
    required int count,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 60.0,
          height: 60.0,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120.0,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildEditProfileForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Image
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 60.0,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!) as ImageProvider
                    : (Provider.of<AuthProvider>(context).user?.photoUrl != null
                        ? NetworkImage(Provider.of<AuthProvider>(context).user!.photoUrl!)
                        : null),
                child: _profileImage == null && 
                      Provider.of<AuthProvider>(context).user?.photoUrl == null
                    ? const Icon(Icons.person, size: 60.0, color: Colors.grey)
                    : null,
              ),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20.0,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24.0),
          
          // Name Field
          CustomTextField(
            controller: _nameController,
            labelText: 'Full Name',
            prefixIcon: const Icon(Icons.person),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16.0),
          
          // Phone Field
          CustomTextField(
            controller: _phoneController,
            labelText: 'Phone Number',
            prefixIcon: const Icon(Icons.phone),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                // Simple validation for demonstration
                if (value.length < 10) {
                  return 'Please enter a valid phone number';
                }
              }
              return null;
            },
          ),
          
          const SizedBox(height: 32.0),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isEditing = false;
                      _profileImage = null;
                      _loadUserData();
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: CustomButton(
                  text: 'Save',
                  isLoading: _isLoading || _isUploading,
                  onPressed: _saveProfile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMyItemsList() {
    if (_myItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64.0,
              color: Colors.grey,
            ),
            const SizedBox(height: 16.0),
            const Text(
              'No items reported yet',
              style: TextStyle(
                fontSize: 18.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8.0),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.itemForm);
              },
              icon: const Icon(Icons.add),
              label: const Text('Report an Item'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _myItems.length,
      itemBuilder: (context, index) {
        final item = _myItems[index];
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 2.0,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            leading: Container(
              width: 60.0,
              height: 60.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                image: item.imageUrls.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(item.imageUrls.first),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey.shade200,
              ),
              child: item.imageUrls.isEmpty
                  ? const Icon(Icons.image, color: Colors.grey)
                  : null,
            ),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4.0),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: item.type == ItemType.lost
                            ? Colors.orange
                            : Colors.green,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        item.type == ItemType.lost ? 'LOST' : 'FOUND',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    if (item.isResolved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: const Text(
                          'RESOLVED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text(item.locationName),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.itemDetails,
                arguments: {'itemId': item.id},
              );
            },
          ),
        );
      },
    );
  }
}