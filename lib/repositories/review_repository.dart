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
    final snapshot = await _firestore.collection(FirestoreCollections.reviews)
        .where('placeId', isEqualTo: placeId)
        .orderBy('createdAt', descending: true).limit(limit).get();
    return snapshot.docs.map(Review.fromQueryDoc).where((r) => r.text.trim().isNotEmpty).toList();
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
