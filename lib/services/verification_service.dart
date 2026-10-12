import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';
import '../models/verification_record.dart';

class VerificationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  VerificationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Fetch public verification records for a place
  Future<List<VerificationRecord>> getVerificationRecords(
    String placeId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.verificationRecords)
          .where('placeId', isEqualTo: placeId)
          .get();

      return snapshot.docs.map(VerificationRecord.fromFirestore).toList();
    } catch (_) {
      return [];
    }
  }

  /// Check verification authority record for a specific feature or overall place
  Future<VerificationRecord?> getFeatureVerificationRecord(
    String placeId,
    String feature,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.verificationRecords)
          .where('placeId', isEqualTo: placeId)
          .where('feature', isEqualTo: feature)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return VerificationRecord.fromFirestore(snapshot.docs.first);
      }
    } catch (_) {}
    return null;
  }
}
