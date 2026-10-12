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
    } catch (_) {}
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

    final existingDoc = await reviewRef.get();
    final existingText = existingDoc.exists
        ? (existingDoc.data()?['text'] as String? ?? '')
        : '';
    final newText = optionalText != null ? optionalText.trim() : existingText;

    final data = <String, dynamic>{
      'placeId': placeId,
      'userId': user.uid,
      'userName': userName,
      'rating': rating,
      'text': newText,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existingDoc.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await reviewRef.set(data, SetOptions(merge: true));

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

    final docId = '${placeId}_${user.uid}';
    final userName = await _resolveUserName(user.uid);
    final reviewRef = _firestore
        .collection(FirestoreCollections.reviews)
        .doc(docId);

    final existingDoc = await reviewRef.get();
    final isNew = !existingDoc.exists;

    final data = <String, dynamic>{
      'placeId': placeId,
      'userId': user.uid,
      'userName': userName,
      'rating': rating,
      'text': trimmedText,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isNew) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await reviewRef.set(data, SetOptions(merge: true));

    // Update place aggregates accurately
    await _recalculatePlaceAggregate(
      placeId,
      userRating: rating,
      userText: trimmedText,
    );

    return Review(
      id: docId,
      placeId: placeId,
      userId: user.uid,
      userName: userName,
      text: trimmedText,
      rating: rating,
      createdAt: isNew
          ? DateTime.now()
          : (existingDoc.data()?['createdAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
      updatedAt: DateTime.now(),
    );
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

    final docs = snapshot.docs;
    if (docs.isEmpty) {
      try {
        await _firestore
            .collection(FirestoreCollections.places)
            .doc(placeId)
            .update({
              'ratingAverage': 0.0,
              'ratingCount': 0,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (_) {}
      return RatingCalculationResult(
        average: 0.0,
        count: 0,
        userRating: userRating,
        userReviewText: userText,
      );
    }

    int totalSum = 0;
    int count = 0;
    for (final doc in docs) {
      final r = doc.data()['rating'] as int?;
      if (r != null && r >= 1 && r <= 5) {
        totalSum += r;
        count++;
      }
    }

    final average = count > 0 ? (totalSum / count) : 0.0;
    final roundedAverage = double.parse(average.toStringAsFixed(1));

    try {
      await _firestore
          .collection(FirestoreCollections.places)
          .doc(placeId)
          .update({
            'ratingAverage': roundedAverage,
            'ratingCount': count,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      // If client cannot update place directly, the aggregate calculated from query is still returned
    }

    return RatingCalculationResult(
      average: roundedAverage,
      count: count,
      userRating: userRating,
      userReviewText: userText,
    );
  }
}
