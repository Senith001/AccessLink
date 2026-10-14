import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/database/firestore_collections.dart';
import '../models/verification_record.dart';
class VerificationService {
  final FirebaseFirestore _firestore;
  VerificationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  Future<List<VerificationRecord>> getVerificationRecords(String placeId) async {
    final snapshot = await _firestore.collection(FirestoreCollections.verificationRecords)
        .where('placeId', isEqualTo: placeId).get();
    final place = await _firestore.collection(FirestoreCollections.places).doc(placeId).get();
    final features = place.data()?['accessibility'];
    return snapshot.docs.where((doc) {
      final data = doc.data();
      final feature = features is Map ? features[data['feature']] : null;
      return data['status'] == 'verified' && feature is Map && feature['verified'] == true &&
          data['available'] == feature['available'] && data['notes'] == feature['notes'];
    }).map(VerificationRecord.fromFirestore).toList();
  }
  Future<VerificationRecord?> getFeatureVerificationRecord(String placeId, String feature) async {
    final records = await getVerificationRecords(placeId);
    final matches = records.where((r) => r.feature == feature).toList();
    matches.sort((a,b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    return matches.isEmpty ? null : matches.first;
  }
}
