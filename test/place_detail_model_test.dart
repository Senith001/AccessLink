import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:accesslink/models/place_detail.dart';

// Mock DocumentSnapshot for testing
class MockDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic>? _data;

  MockDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;

  // Stub implementations for other required methods
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('AccessibilityFeature.fromMap', () {
    test('creates feature with full map data', () {
      final map = {
        'available': true,
        'notes': 'Ramp entrance available',
        'verified': true,
        'lastUpdated': null, // DateTime conversion would require Timestamp mock
      };

      final feature = AccessibilityFeature.fromMap(map);

      expect(feature.available, isTrue);
      expect(feature.notes, equals('Ramp entrance available'));
      expect(feature.verified, isTrue);
      expect(feature.lastUpdated, isNull);
    });

    test('creates feature with null map using defaults', () {
      final feature = AccessibilityFeature.fromMap(null);

      expect(feature.available, isFalse);
      expect(feature.notes, equals(''));
      expect(feature.verified, isFalse);
      expect(feature.lastUpdated, isNull);
    });

    test('creates feature with partial map using defaults for missing fields', () {
      final map = {'available': true};

      final feature = AccessibilityFeature.fromMap(map);

      expect(feature.available, isTrue);
      expect(feature.notes, equals(''));
      expect(feature.verified, isFalse);
      expect(feature.lastUpdated, isNull);
    });
  });

  group('DayHours.fromMap', () {
    test('creates hours with open and close times', () {
      final map = {
        'open': '09:00',
        'close': '18:00',
        'closed': false,
      };

      final hours = DayHours.fromMap(map);

      expect(hours.open, equals('09:00'));
      expect(hours.close, equals('18:00'));
      expect(hours.closed, isFalse);
      expect(hours.display, equals('09:00 – 18:00'));
    });

    test('creates closed hours when closed is true', () {
      final map = {
        'open': '09:00',
        'close': '18:00',
        'closed': true,
      };

      final hours = DayHours.fromMap(map);

      expect(hours.display, equals('Closed'));
    });

    test('creates closed hours when times are empty', () {
      final map = {
        'open': '',
        'close': '',
        'closed': false,
      };

      final hours = DayHours.fromMap(map);

      expect(hours.display, equals('Closed'));
    });

    test('creates closed hours with null map using defaults', () {
      final hours = DayHours.fromMap(null);

      expect(hours.open, equals(''));
      expect(hours.close, equals(''));
      expect(hours.closed, isTrue);
      expect(hours.display, equals('Closed'));
    });
  });

  group('ContactInfo.fromMap', () {
    test('creates contact info with all fields', () {
      final map = {
        'phone': '+1-555-0123',
        'email': 'info@example.com',
        'website': 'https://example.com',
      };

      final contact = ContactInfo.fromMap(map);

      expect(contact.phone, equals('+1-555-0123'));
      expect(contact.email, equals('info@example.com'));
      expect(contact.website, equals('https://example.com'));
      expect(contact.hasAny, isTrue);
    });

    test('creates empty contact info with null map', () {
      final contact = ContactInfo.fromMap(null);

      expect(contact.phone, equals(''));
      expect(contact.email, equals(''));
      expect(contact.website, equals(''));
      expect(contact.hasAny, isFalse);
    });

    test('hasAny returns true when at least one field has value', () {
      final contactWithPhone = ContactInfo.fromMap({'phone': '+1-555-0123'});
      final contactWithEmail = ContactInfo.fromMap({'email': 'test@example.com'});
      final contactWithWebsite = ContactInfo.fromMap({'website': 'example.com'});

      expect(contactWithPhone.hasAny, isTrue);
      expect(contactWithEmail.hasAny, isTrue);
      expect(contactWithWebsite.hasAny, isTrue);
    });

    test('hasAny returns false when all fields are empty', () {
      final contact = ContactInfo.fromMap({
        'phone': '',
        'email': '',
        'website': '',
      });

      expect(contact.hasAny, isFalse);
    });
  });

  group('PlaceDetail constants', () {
    test('featureOrder contains exactly 7 keys', () {
      expect(PlaceDetail.featureOrder.length, equals(7));
    });

    test('featureLabels covers all feature order keys', () {
      expect(PlaceDetail.featureLabels.length, equals(7));
      
      for (final key in PlaceDetail.featureOrder) {
        expect(PlaceDetail.featureLabels.containsKey(key), isTrue,
            reason: 'featureLabels missing key: $key');
      }
    });

    test('featureLabels has descriptive labels for each key', () {
      final expectedLabels = {
        'wheelchairAccessible': 'Wheelchair Accessible',
        'accessibleToilet': 'Accessible Toilet',
        'elevator': 'Elevator',
        'accessibleParking': 'Accessible Parking',
        'tactilePaving': 'Tactile Paving',
        'audioSupport': 'Audio Support',
        'hearingSupport': 'Hearing Support',
      };

      expect(PlaceDetail.featureLabels, equals(expectedLabels));
    });
  });

  group('PlaceDetail.fromFirestore', () {
    test('creates place with minimal legacy document (defaults placeVerified=false)', () {
      final doc = MockDocumentSnapshot('test-id', {
        'name': 'Test Place',
        'description': 'Test Description',
        'categoryName': 'Restaurant',
        'address': '123 Test St',
        'district': 'Test District',
        'city': 'Test City',
        'accessibility': <String, dynamic>{},
        'openingHours': <String, dynamic>{},
        'photos': <String>[],
        'contact': <String, dynamic>{},
        'accessibilityScore': 50,
        'ratingAverage': 4.2,
        'ratingCount': 10,
        'isVerified': true, // Legacy field - should not affect placeVerified
      });

      final place = PlaceDetail.fromFirestore(doc);

      expect(place.id, equals('test-id'));
      expect(place.name, equals('Test Place'));
      expect(place.isVerified, isTrue); // Legacy field preserved
      expect(place.placeVerified, isFalse); // New field defaults to false
      expect(place.verifiedBy, isNull);
      expect(place.verifiedAt, isNull);
    });

    test('creates place with explicit placeVerified field', () {
      final verifiedAt = DateTime(2024, 1, 15, 10, 30);
      final doc = MockDocumentSnapshot('test-id', {
        'name': 'Verified Place',
        'description': 'Test Description',
        'categoryName': 'Restaurant',
        'address': '123 Test St',
        'district': 'Test District',
        'city': 'Test City',
        'accessibility': <String, dynamic>{},
        'openingHours': <String, dynamic>{},
        'photos': <String>[],
        'contact': <String, dynamic>{},
        'accessibilityScore': 85,
        'ratingAverage': 4.5,
        'ratingCount': 20,
        'isVerified': false, // Legacy field
        'placeVerified': true, // Explicit staff verification
        'verifiedBy': 'admin@example.com',
        'verifiedAt': Timestamp.fromDate(verifiedAt),
      });

      final place = PlaceDetail.fromFirestore(doc);

      expect(place.id, equals('test-id'));
      expect(place.name, equals('Verified Place'));
      expect(place.isVerified, isFalse); // Legacy field
      expect(place.placeVerified, isTrue); // New explicit field
      expect(place.verifiedBy, equals('admin@example.com'));
      expect(place.verifiedAt, equals(verifiedAt));
    });

    test('handles null/missing verification fields gracefully', () {
      final doc = MockDocumentSnapshot('test-id', {
        'name': 'Test Place',
        'description': 'Test Description',
        'categoryName': 'Restaurant',
        'address': '123 Test St',
        'district': 'Test District',
        'city': 'Test City',
        'accessibility': <String, dynamic>{},
        'openingHours': <String, dynamic>{},
        'photos': <String>[],
        'contact': <String, dynamic>{},
        'accessibilityScore': 0,
        'ratingAverage': 0.0,
        'ratingCount': 0,
        // Missing isVerified, placeVerified, verifiedBy, verifiedAt
      });

      final place = PlaceDetail.fromFirestore(doc);

      expect(place.isVerified, isFalse); // Default false
      expect(place.placeVerified, isFalse); // Default false
      expect(place.verifiedBy, isNull);
      expect(place.verifiedAt, isNull);
    });

    test('preserves explicit false values for verification fields', () {
      final doc = MockDocumentSnapshot('test-id', {
        'name': 'Test Place',
        'description': 'Test Description',
        'categoryName': 'Restaurant',
        'address': '123 Test St',
        'district': 'Test District',
        'city': 'Test City',
        'accessibility': <String, dynamic>{},
        'openingHours': <String, dynamic>{},
        'photos': <String>[],
        'contact': <String, dynamic>{},
        'accessibilityScore': 0,
        'ratingAverage': 0.0,
        'ratingCount': 0,
        'isVerified': false,
        'placeVerified': false,
        'verifiedBy': null,
        'verifiedAt': null,
      });

      final place = PlaceDetail.fromFirestore(doc);

      expect(place.isVerified, isFalse);
      expect(place.placeVerified, isFalse);
      expect(place.verifiedBy, isNull);
      expect(place.verifiedAt, isNull);
    });
  });
}