import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a written accessibility review for a place.
/// Document ID is deterministic (`userId`) within `places/{placeId}/reviews/{userId}`
/// ensuring each user has at most one review per place and can edit their own.
class PlaceReview {
  final String id;
  final String placeId;
  final String userId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlaceReview({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlaceReview.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PlaceReview(
      id: doc.id,
      placeId: data['placeId'] ?? '',
      userId: data['userId'] ?? doc.id,
      authorName: (data['authorName'] as String?)?.isNotEmpty == true
          ? data['authorName'] as String
          : 'AccessLink Contributor',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'placeId': placeId,
      'userId': userId,
      'authorName': authorName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PlaceReview copyWith({
    String? content,
    String? authorName,
    DateTime? updatedAt,
  }) {
    return PlaceReview(
      id: id,
      placeId: placeId,
      userId: userId,
      authorName: authorName ?? this.authorName,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
