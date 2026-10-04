import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/firestore_collections.dart';
import '../models/review.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore;

  ReviewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<Review>> getReviewsForPlace(String placeId, {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirestoreCollections.reviews)
          .where('placeId', isEqualTo: placeId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Review.fromQueryDoc(doc))
          .toList();
    } catch (e) {
      // Return empty list for graceful handling
      return [];
    }
  }
}