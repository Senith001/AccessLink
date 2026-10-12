import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/database/firestore_collections.dart';
import '../models/review.dart';
import '../services/rating_review_service.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore;
  final RatingReviewService _ratingReviewService;

  ReviewRepository({
    FirebaseFirestore? firestore,
    RatingReviewService? ratingReviewService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _ratingReviewService =
           ratingReviewService ?? RatingReviewService(firestore: firestore);

  Future<List<Review>> getReviewsForPlace(
    String placeId, {
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(FirestoreCollections.reviews)
          .where('placeId', isEqualTo: placeId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => Review.fromQueryDoc(doc)).toList();
    } catch (e) {
      // In case compound index isn't built yet, fallback to fetching by placeId and sorting locally
      try {
        final querySnapshot = await _firestore
            .collection(FirestoreCollections.reviews)
            .where('placeId', isEqualTo: placeId)
            .limit(limit)
            .get();

        final list = querySnapshot.docs
            .map((doc) => Review.fromQueryDoc(doc))
            .toList();

        list.sort((a, b) {
          final aTime = a.createdAt ?? DateTime(2000);
          final bTime = b.createdAt ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });

        return list;
      } catch (_) {
        return [];
      }
    }
  }

  Future<Review?> getUserReviewForPlace(String placeId) {
    return _ratingReviewService.getUserReviewForPlace(placeId);
  }

  Future<RatingCalculationResult> submitOrUpdateRating({
    required String placeId,
    required int rating,
    String? optionalText,
  }) {
    return _ratingReviewService.submitOrUpdateRating(
      placeId: placeId,
      rating: rating,
      optionalText: optionalText,
    );
  }

  Future<Review> submitReview({
    required String placeId,
    required int rating,
    required String text,
  }) {
    return _ratingReviewService.submitReview(
      placeId: placeId,
      rating: rating,
      text: text,
    );
  }
}
