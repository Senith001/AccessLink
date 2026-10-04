import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String placeId;
  final String userId;
  final String userName;
  final String text;
  final int rating;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.rating,
    this.createdAt,
  });

  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('Document data is null');
    }

    // Ensure rating is clamped to valid range
    final rawRating = data['rating'] as int? ?? 0;
    final clampedRating = rawRating < 1 ? 0 : (rawRating > 5 ? 5 : rawRating);

    return Review(
      id: doc.id,
      placeId: data['placeId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      rating: clampedRating,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Review.fromQueryDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    // Ensure rating is clamped to valid range
    final rawRating = data['rating'] as int? ?? 0;
    final clampedRating = rawRating < 1 ? 0 : (rawRating > 5 ? 5 : rawRating);

    return Review(
      id: doc.id,
      placeId: data['placeId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      rating: clampedRating,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}