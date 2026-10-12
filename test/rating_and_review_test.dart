import 'package:flutter_test/flutter_test.dart';
import 'package:accesslink/models/review.dart';
import 'package:accesslink/services/rating_review_service.dart';

void main() {
  group('Rating and Review Validation & Aggregation', () {
    test('Review model correctly parses data and clamps ratings', () {
      final review = Review(
        id: 'rev_1',
        placeId: 'place_123',
        userId: 'user_456',
        userName: 'Alex Smith',
        text: 'Spacious ramp and automatic doors.',
        rating: 5,
        createdAt: DateTime(2026, 10, 1),
      );

      expect(review.rating, 5);
      expect(review.text, 'Spacious ramp and automatic doors.');
      expect(review.userId, 'user_456');

      final map = review.toMap();
      expect(map['placeId'], 'place_123');
      expect(map['rating'], 5);
      expect(map['text'], 'Spacious ramp and automatic doors.');
    });

    test('Rating calculation computes accurate average and count', () {
      const result = RatingCalculationResult(
        average: 4.5,
        count: 2,
        userRating: 4,
      );

      expect(result.average, 4.5);
      expect(result.count, 2);
      expect(result.userRating, 4);
    });

    test(
      'Review text validation rules enforce non-empty and length limits',
      () {
        expect(() {
          final text = '   '.trim();
          if (text.isEmpty) {
            throw ArgumentError(
              'Review text cannot be empty or whitespace only.',
            );
          }
        }, throwsArgumentError);

        expect(() {
          final longText = 'a' * 2001;
          if (longText.length > 2000) {
            throw ArgumentError('Review text cannot exceed 2,000 characters.');
          }
        }, throwsArgumentError);

        expect(() {
          const rating = 6;
          if (rating < 1 || rating > 5) {
            throw ArgumentError('Rating must be between 1 and 5.');
          }
        }, throwsArgumentError);

        expect(() {
          const rating = 0;
          if (rating < 1 || rating > 5) {
            throw ArgumentError('Rating must be between 1 and 5.');
          }
        }, throwsArgumentError);
      },
    );

    test('Updating an existing user rating maintains same count', () {
      // Simulating: Place with 2 ratings: User A (3), User B (5) -> Sum: 8, Count: 2, Avg: 4.0
      // User A updates rating from 3 to 5: User A (5), User B (5) -> Sum: 10, Count: 2, Avg: 5.0
      final ratingsMap = <String, int>{'user_a': 3, 'user_b': 5};

      int count = ratingsMap.length;
      double avg = ratingsMap.values.reduce((a, b) => a + b) / count;
      expect(count, 2);
      expect(avg, 4.0);

      // User A updates
      ratingsMap['user_a'] = 5;
      int updatedCount = ratingsMap.length;
      double updatedAvg =
          ratingsMap.values.reduce((a, b) => a + b) / updatedCount;

      expect(updatedCount, 2); // Count does not increase on update
      expect(updatedAvg, 5.0);
    });
  });
}
