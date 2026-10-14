import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:accesslink/repositories/place_repository.dart';
import 'package:accesslink/models/place_detail.dart';

void main() {
  group('PlaceRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PlaceRepository placeRepository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      placeRepository = PlaceRepository(firestore: fakeFirestore);
    });

    group('findPlaceDetailByNameAndLocation', () {
      test('returns null when no places found', () async {
        final result = await placeRepository.findPlaceDetailByNameAndLocation(
          name: 'Nonexistent Place',
          latitude: 6.9271,
          longitude: 79.8612,
        );

        expect(result, isNull);
      });

      test('returns null when place found but outside radius', () async {
        // Add a place far away from the search location
        await fakeFirestore
            .collection('places')
            .doc('test-place')
            .set({
          'name': 'Test Place',
          'nameLower': 'test place',
          'location': GeoPoint(0, 0), // Very far from search location
          'categoryName': 'Restaurant',
          'address': 'Test Address',
          'district': 'Test District',
          'city': 'Test City',
          'accessibility': {},
          'openingHours': {},
          'contact': {},
          'photos': <String>[],
          'accessibilityScore': 0,
          'isVerified': false,
          'placeVerified': false,
          'ratingAverage': 0.0,
          'ratingCount': 0,
        });

        final result = await placeRepository.findPlaceDetailByNameAndLocation(
          name: 'Test Place',
          latitude: 6.9271,
          longitude: 79.8612,
          radiusMeters: 250,
        );

        expect(result, isNull);
      });

      test('returns place when found within radius', () async {
        // Add a place close to the search location (Colombo coordinates)
        await fakeFirestore
            .collection('places')
            .doc('test-place')
            .set({
          'name': 'Test Place',
          'nameLower': 'test place',
          'location': GeoPoint(6.9271, 79.8612), // Same location as search
          'categoryName': 'Restaurant',
          'address': 'Test Address',
          'district': 'Test District',
          'city': 'Test City',
          'description': 'Test Description',
          'accessibility': {},
          'openingHours': {},
          'contact': {},
          'photos': <String>[],
          'accessibilityScore': 0,
          'isVerified': false,
          'placeVerified': false,
          'ratingAverage': 0.0,
          'ratingCount': 0,
        });

        final result = await placeRepository.findPlaceDetailByNameAndLocation(
          name: 'Test Place',
          latitude: 6.9271,
          longitude: 79.8612,
          radiusMeters: 250,
        );

        expect(result, isNotNull);
        expect(result!.name, equals('Test Place'));
        expect(result.categoryName, equals('Restaurant'));
        expect(result.latitude, equals(6.9271));
        expect(result.longitude, equals(79.8612));
      });

      test('returns nearest place when multiple matches found', () async {
        // Add a place close to search location
        await fakeFirestore
            .collection('places')
            .doc('test-place-1')
            .set({
          'name': 'Test Restaurant',
          'nameLower': 'test restaurant',
          'location': GeoPoint(6.9271, 79.8612), // Same as search location
          'categoryName': 'Restaurant',
          'address': 'Close Address',
          'district': 'Test District',
          'city': 'Test City',
          'description': 'Close Restaurant',
          'accessibility': {},
          'openingHours': {},
          'contact': {},
          'photos': <String>[],
          'accessibilityScore': 0,
          'isVerified': false,
          'placeVerified': false,
          'ratingAverage': 0.0,
          'ratingCount': 0,
        });

        // Add another place with same name but farther away (but still within radius)
        await fakeFirestore
            .collection('places')
            .doc('test-place-2')
            .set({
          'name': 'Test Restaurant',
          'nameLower': 'test restaurant',
          'location': GeoPoint(6.9290, 79.8630), // Slightly farther
          'categoryName': 'Restaurant',
          'address': 'Far Address',
          'district': 'Test District',
          'city': 'Test City',
          'description': 'Far Restaurant',
          'accessibility': {},
          'openingHours': {},
          'contact': {},
          'photos': <String>[],
          'accessibilityScore': 0,
          'isVerified': false,
          'placeVerified': false,
          'ratingAverage': 0.0,
          'ratingCount': 0,
        });

        final result = await placeRepository.findPlaceDetailByNameAndLocation(
          name: 'Test Restaurant',
          latitude: 6.9271,
          longitude: 79.8612,
          radiusMeters: 5000, // Large radius to include both
        );

        expect(result, isNotNull);
        expect(result!.name, equals('Test Restaurant'));
        // Should return the closer one
        expect(result.description, equals('Close Restaurant'));
      });

      test('handles malformed documents gracefully', () async {
        // Add a malformed document
        await fakeFirestore
            .collection('places')
            .doc('malformed-place')
            .set({
          'name': 'Test Place',
          'nameLower': 'test place',
          // Missing required fields to make it malformed
        });

        final result = await placeRepository.findPlaceDetailByNameAndLocation(
          name: 'Test Place',
          latitude: 6.9271,
          longitude: 79.8612,
        );

        expect(result, isNull);
      });

      test('handles firestore errors gracefully', () async {
        // Create a fake firestore and add a corrupted collection that will cause errors
        final errorFirestore = FakeFirebaseFirestore();
        final errorRepository = PlaceRepository(firestore: errorFirestore);
        
        // Add a document with corrupted data that will throw during deserialization
        await errorFirestore
            .collection('places')
            .doc('corrupted-place')
            .set({
          'name': 'Test Place',
          'nameLower': 'test place',
          'location': 'invalid_location_data', // This should be a GeoPoint but isn't
        });
        
        final result = await errorRepository.findPlaceDetailByNameAndLocation(
          name: 'Test Place',
          latitude: 6.9271,
          longitude: 79.8612,
        );

        expect(result, isNull);
      });
    });
  });
}