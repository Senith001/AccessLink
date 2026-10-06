import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';
import '../models/accessibility_rating.dart';

/// Service for submitting and querying accessibility ratings.
///
/// Data model (Firestore):
///   - `places/{placeId}/ratings/{odcId}`  – individual user ratings,
///     where docId == `userId` so each user can have at most one rating
///     per place.
///   - `places/{placeId}` – document with aggregated `averageScore` and
///     `ratingCount` fields, updated atomically via a transaction.
class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Validates that [rating] is between 1 and 5 inclusive.
  static bool isValidRating(int rating) => rating >= 1 && rating <= 5;

  /// Returns the current signed-in user's UID, or `null`.
  String? get _currentUid => _auth.currentUser?.uid;

  /// Submits or updates the current user's rating for [placeId].
  ///
  /// Uses a Firestore transaction to:
  ///   1. Read the user's existing rating (if any).
  ///   2. Read the current aggregate summary.
  ///   3. Write the user rating document (create or overwrite).
  ///   4. Recompute and write the aggregate summary atomically.
  ///
  /// This handles concurrent submissions correctly because transactions
  /// retry on contention.
  Future<void> submitRating({
    required String placeId,
    required int rating,
  }) async {
    if (!isValidRating(rating)) {
      throw ArgumentError('Rating must be between 1 and 5, got $rating');
    }

    final uid = _currentUid;
    if (uid == null) {
      throw StateError('User must be signed in to submit a rating');
    }

    final placeDoc = _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId);
    final userRatingDoc = placeDoc
        .collection(FirestoreCollections.accessibilityRatings)
        .doc(uid);

    await _firestore.runTransaction((transaction) async {
      // 1. Read current user rating (may not exist).
      final userRatingSnap = await transaction.get(userRatingDoc);
      final int? previousRating = userRatingSnap.exists
          ? (userRatingSnap.data()?['rating'] as num?)?.toInt()
          : null;

      // 2. Read current aggregate.
      final placeSnap = await transaction.get(placeDoc);
      final double currentAvg =
          (placeSnap.data()?['averageScore'] as num?)?.toDouble() ?? 0.0;
      final int currentCount =
          (placeSnap.data()?['ratingCount'] as num?)?.toInt() ?? 0;

      // 3. Compute new aggregate.
      double newAvg;
      int newCount;

      if (previousRating != null) {
        // Update: count stays the same, adjust the sum.
        final double currentSum = currentAvg * currentCount;
        newCount = currentCount;
        newAvg = newCount > 0
            ? (currentSum - previousRating + rating) / newCount
            : rating.toDouble();
      } else {
        // New rating: increment count.
        final double currentSum = currentAvg * currentCount;
        newCount = currentCount + 1;
        newAvg = (currentSum + rating) / newCount;
      }

      // 4. Write user rating.
      final now = DateTime.now();
      Timestamp createdAt = Timestamp.fromDate(now);
      if (userRatingSnap.exists && userRatingSnap.data() != null) {
        final existingCreatedAt = userRatingSnap.data()!['createdAt'];
        if (existingCreatedAt is Timestamp) {
          createdAt = existingCreatedAt;
        }
      }

      transaction.set(userRatingDoc, {
        'placeId': placeId,
        'userId': uid,
        'rating': rating,
        'createdAt': createdAt,
        'updatedAt': Timestamp.fromDate(now),
      });

      // 5. Write aggregate.
      transaction.set(
        placeDoc,
        {
          'averageScore': newAvg,
          'ratingCount': newCount,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Fetches the current user's rating for [placeId], or `null` if they
  /// haven't rated yet.
  Future<AccessibilityRating?> getUserRating(String placeId) async {
    final uid = _currentUid;
    if (uid == null) return null;

    final doc = await _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId)
        .collection(FirestoreCollections.accessibilityRatings)
        .doc(uid)
        .get();

    if (!doc.exists) return null;
    return AccessibilityRating.fromFirestore(doc);
  }

  /// Fetches the aggregated accessibility score for [placeId].
  Future<PlaceAccessibilityScore> getPlaceScore(String placeId) async {
    final doc = await _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return PlaceAccessibilityScore.empty();
    }

    return PlaceAccessibilityScore.fromMap(doc.data()!);
  }

  /// Returns a real-time stream of the aggregated score for [placeId].
  Stream<PlaceAccessibilityScore> placeScoreStream(String placeId) {
    return _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return PlaceAccessibilityScore.empty();
      }
      return PlaceAccessibilityScore.fromMap(snap.data()!);
    });
  }
}
