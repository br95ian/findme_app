import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register with email & password
  Future<UserModel> registerWithEmailAndPassword(
      String name, String email, String password) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user == null) {
        throw Exception('Failed to create user');
      }
      
      // Create timestamp
      final now = DateTime.now();
      
      // Create user model
      final user = UserModel(
        uid: userCredential.user!.uid,
        id: userCredential.user!.uid,
        name: name,
        email: email,
        createdAt: now,
        updatedAt: now,
      );
      
      // Save user to Firestore
      await _firestore.collection('users').doc(user.id).set(user.toMap());
      
      return user;
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Login with email & password
  Future<UserModel> loginWithEmailAndPassword(String email, String password) async {
    try {
      // Sign in with Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user == null) {
        throw Exception('Failed to sign in');
      }
      
      // Get user data from Firestore
      final doc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user profile
  Future<UserModel?> getUserProfile() async {
    try {
      if (currentUser == null) return null;
      
      final doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
          
      if (!doc.exists) return null;
      
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to get user profile: ${e.toString()}');
    }
  }

  // Update user profile
  Future<UserModel> updateUserProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    try {
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }
      
      final userDoc = _firestore.collection('users').doc(currentUser!.uid);
      final userSnapshot = await userDoc.get();
      
      if (!userSnapshot.exists) {
        throw Exception('User not found');
      }
      
      final user = UserModel.fromMap(userSnapshot.data() as Map<String, dynamic>);
      
      final updatedUser = user.copyWith(
        name: name,
        phone: phone,
        photoUrl: photoUrl,
      );
      
      await userDoc.update({
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      
      return updatedUser;
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }
}