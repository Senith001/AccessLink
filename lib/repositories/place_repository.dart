import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/firestore_collections.dart';
import '../models/place_detail.dart';
import '../models/search_place.dart';

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

  Future<PlaceDetail?> findPlaceDetailByNameAndLocation({
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = 250,
  }) async {
    try {
      final query = await _firestore
          .collection(FirestoreCollections.places)
          .where('nameLower', isEqualTo: name.trim().toLowerCase())
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final candidates = <PlaceDetail>[];
      for (final doc in query.docs) {
        try {
          final placeDetail = PlaceDetail.fromFirestore(doc);
          if (placeDetail.latitude != null && placeDetail.longitude != null) {
            candidates.add(placeDetail);
          }
        } catch (e) {
          // Skip malformed documents
          continue;
        }
      }

      if (candidates.isEmpty) {
        return null;
      }

      // Find the nearest candidate within radius
      PlaceDetail? nearestPlace;
      double nearestDistanceMeters = double.infinity;

      for (final candidate in candidates) {
        final distanceKm = searchDistanceBetweenInKm(
          latitude,
          longitude,
          candidate.latitude!,
          candidate.longitude!,
        );
        final distanceMeters = distanceKm * 1000;

        if (distanceMeters <= radiusMeters && distanceMeters < nearestDistanceMeters) {
          nearestPlace = candidate;
          nearestDistanceMeters = distanceMeters;
        }
      }

      return nearestPlace;
    } catch (e) {
      // Return null for graceful handling
      return null;
    }
  }
}