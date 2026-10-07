import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import '../domain/auth_repository.dart';
import '../domain/user_profile.dart';

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StreamController<UserProfile?> _authStateController = StreamController<UserProfile?>.broadcast();
  StreamSubscription<fb.User?>? _authSubscription;

  FirebaseAuthRepository() {
    _initListener();
  }

  void _initListener() {
    _authSubscription = _firebaseAuth.authStateChanges().listen((fb.User? fbUser) async {
      if (fbUser == null) {
        _authStateController.add(null);
      } else {
        try {
          final profile = await _fetchUserProfile(fbUser.uid);
          _authStateController.add(profile);
        } catch (e) {
          debugPrint("Error fetching user profile stream: $e");
          // Add a basic profile representation if firestore doc isn't loaded yet
          _authStateController.add(UserProfile(
            uid: fbUser.uid,
            email: fbUser.email ?? '',
            username: fbUser.email?.split('@').first ?? 'user',
            displayName: fbUser.displayName ?? 'New User',
            createdAt: DateTime.now(),
          ));
        }
      }
    });
  }

  Future<UserProfile?> _fetchUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserProfile.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Stream<UserProfile?> get authStateChanges => _authStateController.stream;

  @override
  Future<UserProfile?> getCurrentUser() async {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) return null;
    return await _fetchUserProfile(fbUser.uid);
  }

  @override
  Future<UserProfile> loginWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      final profile = await _fetchUserProfile(uid);
      if (profile != null) {
        return profile;
      }
      // Fallback in case document doesn't exist
      final newProfile = UserProfile(
        uid: uid,
        email: email,
        username: email.split('@').first,
        displayName: credential.user!.displayName ?? email.split('@').first,
        createdAt: DateTime.now(),
      );
      await updateProfile(newProfile);
      return newProfile;
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Authentication failed.');
    }
  }

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      // Check username availability first in Firestore
      final isAvailable = await isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username already taken.');
      }

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      
      // Update display name in Firebase Auth
      await credential.user!.updateDisplayName(displayName);

      final profile = UserProfile(
        uid: uid,
        email: email,
        username: username,
        displayName: displayName,
        xp: 0,
        level: 1,
        badges: [],
        createdAt: DateTime.now(),
      );

      // Save user document in firestore
      await _firestore.collection('users').doc(uid).set(profile.toMap());
      _authStateController.add(profile);
      
      return profile;
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Registration failed.');
    }
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      await _firestore.collection('users').doc(profile.uid).set(
            profile.toMap(),
            SetOptions(merge: true),
          );
      _authStateController.add(profile);
      return profile;
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();
      return query.docs.isEmpty;
    } catch (e) {
      debugPrint("Error checking username availability in Firestore: $e");
      return true; // Fallback in case of rules/offline issues during dev
    }
  }

  @override
  Future<void> deleteAccount(String uid) async {
    try {
      // Delete user profile doc from Firestore
      await _firestore.collection('users').doc(uid).delete();
      
      // Delete user from Firebase Auth
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.delete();
      }
      
      _authStateController.add(null);
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _authStateController.close();
  }
}
