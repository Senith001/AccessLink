import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';
import '../models/place_review.dart';

/// Service managing written reviews for places.
///
/// Design decision on document ID:
/// Each review document is stored under `places/{placeId}/reviews/{userId}` where
/// the document ID is deterministically set to the author's Firebase Auth `uid`.
/// This enforces exactly one review per user per place, allows instant retrieval
/// and editing of the user's existing review, and aligns with Firestore security
/// rules to prevent unauthorized modification by other users.
class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int minContentLength = 5;
  static const int maxContentLength = 1000;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Validates review text.
  /// Throws [ArgumentError] with a clear message if validation fails.
  static String validateReviewContent(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Review text cannot be empty.');
    }
    if (trimmed.length < minContentLength) {
      throw ArgumentError(
        'Review must be at least $minContentLength characters long.',
      );
    }
    if (trimmed.length > maxContentLength) {
      throw ArgumentError(
        'Review cannot exceed $maxContentLength characters.',
      );
    }
    return trimmed;
  }

  /// Submits or updates a written review for [placeId].
  /// Explicitly verifies ownership: only the authenticated user can edit their review.
  Future<void> submitReview({
    required String placeId,
    required String content,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to post a review.');
    }

    final trimmedContent = validateReviewContent(content);
    final uid = user.uid;

    final docRef = _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId)
        .collection(FirestoreCollections.reviews)
        .doc(uid);

    final existingSnap = await docRef.get();
    final now = DateTime.now();

    // Deriving a privacy-conscious display name fallback
    String authorName = user.displayName?.trim() ?? '';
    if (authorName.isEmpty && user.email != null && user.email!.contains('@')) {
      final prefix = user.email!.split('@').first;
      authorName = prefix.length > 3
          ? '${prefix.substring(0, 3)}***'
          : 'Community Member';
    } else if (authorName.isEmpty) {
      authorName = 'AccessLink User';
    }

    if (existingSnap.exists) {
      // Editing existing review - ensure ownership
      final existingUserId = existingSnap.data()?['userId'] as String?;
      if (existingUserId != null && existingUserId != uid) {
        throw StateError('You do not have permission to edit this review.');
      }

      await docRef.update({
        'content': trimmedContent,
        'authorName': authorName,
        'updatedAt': Timestamp.fromDate(now),
      });
    } else {
      // Creating new review
      final review = PlaceReview(
        id: uid,
        placeId: placeId,
        userId: uid,
        authorName: authorName,
        content: trimmedContent,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(review.toFirestore());
    }
  }

  /// Fetches the current user's review for [placeId], or null.
  Future<PlaceReview?> getUserReview(String placeId) async {
    final uid = currentUserId;
    if (uid == null) return null;

    final doc = await _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId)
        .collection(FirestoreCollections.reviews)
        .doc(uid)
        .get();

    if (!doc.exists) return null;
    return PlaceReview.fromFirestore(doc);
  }

  /// Real-time stream of all reviews for [placeId], ordered newest first.
  Stream<List<PlaceReview>> getReviewsStream(String placeId) {
    return _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId)
        .collection(FirestoreCollections.reviews)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => PlaceReview.fromFirestore(doc)).toList());
  }

  /// Deletes the current user's review for [placeId].
  Future<void> deleteReview(String placeId) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('You must be signed in to delete a review.');
    }

    final docRef = _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId)
        .collection(FirestoreCollections.reviews)
        .doc(uid);

    await docRef.delete();
  }
}
