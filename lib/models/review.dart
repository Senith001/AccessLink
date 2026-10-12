import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String placeId;
  final String userId;
  final String userName;
  final String text;
  final int rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Review({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.rating,
    this.createdAt,
    this.updatedAt,
  });

  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('Document data is null');
    }

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
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Review.fromQueryDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

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
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'userId': userId,
      'userName': userName,
      'text': text,
      'rating': rating,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Review copyWith({
    String? id,
    String? placeId,
    String? userId,
    String? userName,
    String? text,
    int? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Review(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      text: text ?? this.text,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
