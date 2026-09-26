import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/database/firestore_collections.dart';
import '../models/place.dart';

class PlaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Place>> getPlaces() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _firestore
            .collection(FirestoreCollections.places)
            .get();

    return snapshot.docs
        .where((doc) => doc.data()['location'] is GeoPoint)
        .map((doc) => Place.fromFirestore(doc))
        .toList();
  }
}