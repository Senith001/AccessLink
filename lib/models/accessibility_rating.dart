import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single user's accessibility rating for a place.
class AccessibilityRating {
  final String id;
  final String placeId;
  final String userId;
  final int rating; // 1–5
  final DateTime createdAt;
  final DateTime updatedAt;

  AccessibilityRating({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
  }) {
    assert(rating >= 1 && rating <= 5, 'Rating must be between 1 and 5');
  }

  factory AccessibilityRating.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return AccessibilityRating(
      id: doc.id,
      placeId: data['placeId'] ?? '',
      userId: data['userId'] ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'placeId': placeId,
      'userId': userId,
      'rating': rating,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// Aggregated accessibility score for a place, stored on the place's
/// ratings summary document.
class PlaceAccessibilityScore {
  final double averageScore;
  final int ratingCount;

  const PlaceAccessibilityScore({
    required this.averageScore,
    required this.ratingCount,
  });

  factory PlaceAccessibilityScore.fromMap(Map<String, dynamic> data) {
    return PlaceAccessibilityScore(
      averageScore: (data['averageScore'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory PlaceAccessibilityScore.empty() {
    return const PlaceAccessibilityScore(averageScore: 0.0, ratingCount: 0);
  }
}
