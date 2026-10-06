import 'package:flutter_test/flutter_test.dart';

import 'package:accesslink/models/accessibility_rating.dart';
import 'package:accesslink/services/rating_service.dart';

void main() {
  group('RatingService validation', () {
    test('isValidRating returns true for valid ratings 1–5', () {
      for (int i = 1; i <= 5; i++) {
        expect(RatingService.isValidRating(i), isTrue,
            reason: 'Rating $i should be valid');
      }
    });

    test('isValidRating returns false for out-of-range ratings', () {
      expect(RatingService.isValidRating(0), isFalse);
      expect(RatingService.isValidRating(6), isFalse);
      expect(RatingService.isValidRating(-1), isFalse);
      expect(RatingService.isValidRating(100), isFalse);
    });
  });

  group('PlaceAccessibilityScore', () {
    test('fromMap parses valid data', () {
      final score = PlaceAccessibilityScore.fromMap({
        'averageScore': 4.5,
        'ratingCount': 10,
      });
      expect(score.averageScore, 4.5);
      expect(score.ratingCount, 10);
    });

    test('fromMap handles missing fields', () {
      final score = PlaceAccessibilityScore.fromMap({});
      expect(score.averageScore, 0.0);
      expect(score.ratingCount, 0);
    });

    test('empty() returns zeroed score', () {
      final score = PlaceAccessibilityScore.empty();
      expect(score.averageScore, 0.0);
      expect(score.ratingCount, 0);
    });
  });

  group('AccessibilityRating model', () {
    test('toFirestore contains all required fields', () {
      final now = DateTime(2026, 9, 29, 12, 0);
      final rating = AccessibilityRating(
        id: 'test-id',
        placeId: 'place-1',
        userId: 'user-1',
        rating: 4,
        createdAt: now,
        updatedAt: now,
      );
      final map = rating.toFirestore();
      expect(map['placeId'], 'place-1');
      expect(map['userId'], 'user-1');
      expect(map['rating'], 4);
      expect(map.containsKey('createdAt'), isTrue);
      expect(map.containsKey('updatedAt'), isTrue);
    });

    test('constructor rejects invalid rating', () {
      expect(
        () => AccessibilityRating(
          id: 'test',
          placeId: 'p',
          userId: 'u',
          rating: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => AccessibilityRating(
          id: 'test',
          placeId: 'p',
          userId: 'u',
          rating: 6,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
