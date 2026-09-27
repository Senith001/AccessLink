import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/firestore_collections.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createUser({
    required String uid,
    required String name,
    required String email,
    String? phone,
    String role = 'user',
    String userType = 'contributor',
    List<String> accessibilityNeeds = const [],
  }) async {
    final userData = {
      'name': name,
      'email': email,
      'role': role,
      'userType': userType,
      'accessibilityNeeds': accessibilityNeeds,
      'textScale': 1.0,
      'highContrast': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Only include phone if it's not null
    if (phone != null) {
      userData['phone'] = phone;
    }

    await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .set(userData, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();
    return doc.data();
  }
}