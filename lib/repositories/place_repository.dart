import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/firestore_collections.dart';
import '../models/place_detail.dart';

class PlaceRepository {
  final FirebaseFirestore _firestore;

  PlaceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<PlaceDetail?> getPlaceDetail(String placeId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.places)
          .doc(placeId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return PlaceDetail.fromFirestore(doc);
    } catch (e) {
      // Return null for graceful handling
      return null;
    }
  }
}