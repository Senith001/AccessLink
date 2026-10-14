import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/firestore_collections.dart';
import '../models/place_detail.dart';
class PlaceRepository {
  final FirebaseFirestore _firestore;
  PlaceRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  Future<PlaceDetail?> getPlaceDetail(String placeId) async {
    final doc = await _firestore.collection(FirestoreCollections.places).doc(placeId).get();
    return doc.exists ? PlaceDetail.fromFirestore(doc) : null;
  }
}
