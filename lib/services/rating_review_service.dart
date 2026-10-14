import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';
import '../models/review.dart';

class RatingCalculationResult {
  final double average;
  final int count;
  final int? userRating;
  final String? userReviewText;

  const RatingCalculationResult({
    required this.average,
    required this.count,
    this.userRating,
    this.userReviewText,
  });
}

class RatingReviewService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  RatingReviewService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Helper to get user display name safely
  Future<String> _resolveUserName(String uid) async {
    try {
      final userDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();
      if (userDoc.exists) {
        final name = userDoc.data()?['name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          return name.trim();
        }
      }
    } catch (_) {}

    final user = _auth.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        return user.displayName!.trim();
      }
      if (user.email != null && user.email!.isNotEmpty) {
        return user.email!.split('@').first;
      }
    }
    return 'Community Contributor';
  }

  /// Get current user's rating & review for a place
  Future<Review?> getUserReviewForPlace(String placeId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final docId = '${placeId}_${user.uid}';
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.reviews)
          .doc(docId)
          .get();
      if (doc.exists && doc.data() != null) {
        return Review.fromFirestore(doc);
      }

      // Fallback query by placeId and userId
      final query = await _firestore
          .collection(FirestoreCollections.reviews)
          .where('placeId', isEqualTo: placeId)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return Review.fromQueryDoc(query.docs.first);
      }
    } on FirebaseException { rethrow; }
    return null;
  }

  /// Submit or update a rating (without requiring review text)
  Future<RatingCalculationResult> submitOrUpdateRating({
    required String placeId,
    required int rating,
    String? optionalText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError(
        'You must be signed in to submit an accessibility rating.',
      );
    }

    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be an integer between 1 and 5.');
    }

    final docId = '${placeId}_${user.uid}';
    final userName = await _resolveUserName(user.uid);
    final reviewRef = _firestore
        .collection(FirestoreCollections.reviews)
        .doc(docId);

    String newText = '';
    await _firestore.runTransaction((tx) async {
      final place = await tx.get(_firestore.collection(FirestoreCollections.places).doc(placeId));
      final existingDoc = await tx.get(reviewRef);
      if (!place.exists) throw StateError('This place no longer exists.');
      newText = optionalText?.trim() ?? (existingDoc.data()?['text'] as String? ?? '');
      if (newText.length > 2000) throw ArgumentError('Review text cannot exceed 2,000 characters.');
      tx.set(reviewRef, {
        'placeId': placeId, 'userId': user.uid, 'userName': userName,
        'rating': rating, 'text': newText,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!existingDoc.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    // Calculate accurate aggregate from all saved ratings for this place
    return await _recalculatePlaceAggregate(
      placeId,
      userRating: rating,
      userText: newText,
    );
  }

  /// Submit or update an accessibility review with text guidance
  Future<Review> submitReview({
    required String placeId,
    required int rating,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError(
        'You must be signed in to submit an accessibility review.',
      );
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw ArgumentError('Review text cannot be empty or whitespace only.');
    }

    if (trimmedText.length > 2000) {
      throw ArgumentError('Review text cannot exceed 2,000 characters.');
    }

    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be an integer between 1 and 5.');
    }

    await submitOrUpdateRating(placeId: placeId, rating: rating, optionalText: trimmedText);
    final saved = await getUserReviewForPlace(placeId);
    if (saved == null) throw StateError('Review saved, but could not be refreshed. Please refresh the page.');
    return saved;
  }

  /// Accurately compute ratings aggregate from trusted query and update place record
  Future<RatingCalculationResult> _recalculatePlaceAggregate(
    String placeId, {
    int? userRating,
    String? userText,
  }) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.reviews)
        .where('placeId', isEqualTo: placeId)
        .get();

    final selected = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in snapshot.docs) {
      final d = doc.data();
      final uid = d['userId'];
      final rating = d['rating'];
      if (uid is! String || rating is! int || rating < 1 || rating > 5) continue;
      final previous = selected[uid];
      final canonical = doc.id == '${placeId}_$uid';
      final oldCanonical = previous?.id == '${placeId}_$uid';
      final time = (d['updatedAt'] as Timestamp?) ?? (d['createdAt'] as Timestamp?);
      final old = previous?.data();
      final oldTime = (old?['updatedAt'] as Timestamp?) ?? (old?['createdAt'] as Timestamp?);
      if (previous == null || (canonical && !oldCanonical) ||
          (canonical == oldCanonical && (time?.millisecondsSinceEpoch ?? 0) > (oldTime?.millisecondsSinceEpoch ?? 0))) {
        selected[uid] = doc;
      }
    }
    final count = selected.length;
    final totalSum = selected.values.fold<int>(0, (sum, doc) => sum + (doc.data()['rating'] as int));
    final average = count > 0 ? (totalSum / count) : 0.0;
    final roundedAverage = double.parse(average.toStringAsFixed(1));

    // Trusted Cloud Function persists the aggregate; the dialog uses this
    // freshly calculated value immediately while the place list updates asynchronously.
    return RatingCalculationResult(
      average: roundedAverage,
      count: count,
      userRating: userRating,
      userReviewText: userText,
    );
  }
}
