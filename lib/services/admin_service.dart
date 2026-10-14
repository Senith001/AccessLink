import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';

/// Service for admin/staff role checking and user management.
/// 
/// Provides DI-friendly role checking that reads from both:
/// 1. User's Firestore document (users/{uid}.role field)
/// 2. Firebase Auth custom claims (token.claims['role'])
/// 
/// Staff = user has role in ['admin', 'moderator'] from EITHER source.
class AdminService {
  AdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  /// Check if current user is staff (admin or moderator)
  Future<bool> isCurrentUserStaff() async {
    final user = currentUser;
    if (user == null) return false;

    // Check both Firestore document and Auth custom claims
    final results = await Future.wait([
      _checkFirestoreRole(user.uid),
      _checkAuthClaims(user),
    ]);

    return results.any((isStaff) => isStaff);
  }

  /// Stream of current user's staff status
  Stream<bool> watchCurrentUserStaffStatus() async* {
    final user = currentUser;
    if (user == null) {
      yield false;
      return;
    }

    // Create combined stream from Firestore role only
    // Note: Auth claims are checked separately due to stream complexity
    await for (final firestoreResult in _watchFirestoreRole(user.uid)) {
      final claimsResult = await _checkAuthClaims(user);
      yield firestoreResult || claimsResult;
    }
  }

  /// Check role from user's Firestore document
  Future<bool> _checkFirestoreRole(String uid) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final role = data['role'] as String?;
      return _isStaffRole(role);
    } catch (e) {
      // If Firestore check fails, don't throw - just return false
      return false;
    }
  }

  /// Watch role from user's Firestore document
  Stream<bool> _watchFirestoreRole(String uid) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final role = data['role'] as String?;
      return _isStaffRole(role);
    }).handleError((error) {
      // If stream fails, emit false rather than error
      return false;
    });
  }

  /// Check role from Firebase Auth custom claims
  Future<bool> _checkAuthClaims(User user) async {
    try {
      final idTokenResult = await user.getIdTokenResult();
      final role = idTokenResult.claims?['role'] as String?;
      return _isStaffRole(role);
    } catch (e) {
      // If Auth claims check fails, don't throw - just return false
      return false;
    }
  }

  /// Check if a role string indicates staff privileges
  bool _isStaffRole(String? role) {
    if (role == null) return false;
    return role == 'admin' || role == 'moderator';
  }
}