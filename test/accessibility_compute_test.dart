import 'package:flutter_test/flutter_test.dart';
import 'package:accesslink/utils/accessibility_compute.dart';

void main() {
  group('accessibility_compute', () {
    group('kAccessibilityFeatureKeys', () {
      test('should contain the correct 7 feature keys', () {
        expect(kAccessibilityFeatureKeys, hasLength(7));
        expect(kAccessibilityFeatureKeys, contains('wheelchairAccessible'));
        expect(kAccessibilityFeatureKeys, contains('accessibleToilet'));
        expect(kAccessibilityFeatureKeys, contains('elevator'));
        expect(kAccessibilityFeatureKeys, contains('accessibleParking'));
        expect(kAccessibilityFeatureKeys, contains('tactilePaving'));
        expect(kAccessibilityFeatureKeys, contains('audioSupport'));
        expect(kAccessibilityFeatureKeys, contains('hearingSupport'));
      });
    });

    group('computeAccessibilityScore', () {
      test('should return 0 for 0/7 available features', () {
        final accessibility = {
          'wheelchairAccessible': {'available': false},
          'accessibleToilet': {'available': false},
          'elevator': {'available': false},
          'accessibleParking': {'available': false},
          'tactilePaving': {'available': false},
          'audioSupport': {'available': false},
          'hearingSupport': {'available': false},
        };
        
        expect(computeAccessibilityScore(accessibility), equals(0));
      });

      test('should return 43 for 3/7 available features (rounded)', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true},
          'accessibleToilet': {'available': true},
          'elevator': {'available': false},
          'accessibleParking': {'available': true},
          'tactilePaving': {'available': false},
          'audioSupport': {'available': false},
          'hearingSupport': {'available': false},
        };
        
        // 3/7 * 100 = 42.857... rounds to 43
        expect(computeAccessibilityScore(accessibility), equals(43));
      });

      test('should return 71 for 5/7 available features (rounded)', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true},
          'accessibleToilet': {'available': true},
          'elevator': {'available': true},
          'accessibleParking': {'available': true},
          'tactilePaving': {'available': false},
          'audioSupport': {'available': true},
          'hearingSupport': {'available': false},
        };
        
        // 5/7 * 100 = 71.428... rounds to 71
        expect(computeAccessibilityScore(accessibility), equals(71));
      });

      test('should return 100 for 7/7 available features', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true},
          'accessibleToilet': {'available': true},
          'elevator': {'available': true},
          'accessibleParking': {'available': true},
          'tactilePaving': {'available': true},
          'audioSupport': {'available': true},
          'hearingSupport': {'available': true},
        };
        
        expect(computeAccessibilityScore(accessibility), equals(100));
      });

      test('should handle missing keys as not available', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true},
          'accessibleToilet': {'available': true},
          // Missing other keys should default to not available
        };
        
        // 2/7 * 100 = 28.571... rounds to 29
        expect(computeAccessibilityScore(accessibility), equals(29));
      });

      test('should handle null available values as not available', () {
        final accessibility = {
          'wheelchairAccessible': {'available': null},
          'accessibleToilet': {'available': true},
          'elevator': null, // Entire feature is null
          'accessibleParking': {'available': false},
          'tactilePaving': {'available': true},
          'audioSupport': {'available': true},
          'hearingSupport': {'available': true},
        };
        
        // Only 4 are explicitly true, null treated as false
        // 4/7 * 100 = 57.142... rounds to 57
        expect(computeAccessibilityScore(accessibility), equals(57));
      });

      test('should handle empty accessibility map', () {
        final accessibility = <String, dynamic>{};
        
        expect(computeAccessibilityScore(accessibility), equals(0));
      });
    });

    group('computeAccessibilityFlags', () {
      test('should map each key correctly when all available', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true},
          'accessibleToilet': {'available': true},
          'elevator': {'available': true},
          'accessibleParking': {'available': true},
          'tactilePaving': {'available': true},
          'audioSupport': {'available': true},
          'hearingSupport': {'available': true},
        };
        
        final flags = computeAccessibilityFlags(accessibility);
        
        expect(flags['hasWheelchairAccess'], isTrue);
        expect(flags['hasAccessibleToilet'], isTrue);
        expect(flags['hasElevator'], isTrue);
        expect(flags['hasAccessibleParking'], isTrue);
        expect(flags['hasTactilePaving'], isTrue);
        expect(flags['hasAudioSupport'], isTrue);
        expect(flags['hasHearingSupport'], isTrue);
      });

      test('should map each key correctly when all not available', () {
        final accessibility = {
          'wheelchairAccessible': {'available': false},
          'accessibleToilet': {'available': false},
          'elevator': {'available': false},
          'accessibleParking': {'available': false},
          'tactilePaving': {'available': false},
          'audioSupport': {'available': false},
          'hearingSupport': {'available': false},
        };
        
        final flags = computeAccessibilityFlags(accessibility);
        
        expect(flags['hasWheelchairAccess'], isFalse);
        expect(flags['hasAccessibleToilet'], isFalse);
        expect(flags['hasElevator'], isFalse);
        expect(flags['hasAccessibleParking'], isFalse);
        expect(flags['hasTactilePaving'], isFalse);
        expect(flags['hasAudioSupport'], isFalse);
        expect(flags['hasHearingSupport'], isFalse);
      });

      test('should map mixed availability correctly', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true},
          'accessibleToilet': {'available': false},
          'elevator': {'available': true},
          'accessibleParking': {'available': false},
          'tactilePaving': {'available': true},
          'audioSupport': {'available': false},
          'hearingSupport': {'available': true},
        };
        
        final flags = computeAccessibilityFlags(accessibility);
        
        expect(flags['hasWheelchairAccess'], isTrue);
        expect(flags['hasAccessibleToilet'], isFalse);
        expect(flags['hasElevator'], isTrue);
        expect(flags['hasAccessibleParking'], isFalse);
        expect(flags['hasTactilePaving'], isTrue);
        expect(flags['hasAudioSupport'], isFalse);
        expect(flags['hasHearingSupport'], isTrue);
      });

      test('should default to false for missing keys', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true},
          // All other keys missing
        };
        
        final flags = computeAccessibilityFlags(accessibility);
        
        expect(flags['hasWheelchairAccess'], isTrue);
        expect(flags['hasAccessibleToilet'], isFalse);
        expect(flags['hasElevator'], isFalse);
        expect(flags['hasAccessibleParking'], isFalse);
        expect(flags['hasTactilePaving'], isFalse);
        expect(flags['hasAudioSupport'], isFalse);
        expect(flags['hasHearingSupport'], isFalse);
      });

      test('should default to false for null available values', () {
        final accessibility = {
          'wheelchairAccessible': {'available': null},
          'accessibleToilet': null, // Entire feature is null
          'elevator': {'available': true},
          'accessibleParking': {}, // Missing available key
          'tactilePaving': {'available': false},
          'audioSupport': {'available': true},
          'hearingSupport': {'available': null},
        };
        
        final flags = computeAccessibilityFlags(accessibility);
        
        expect(flags['hasWheelchairAccess'], isFalse); // null -> false
        expect(flags['hasAccessibleToilet'], isFalse); // null feature -> false
        expect(flags['hasElevator'], isTrue); // explicitly true
        expect(flags['hasAccessibleParking'], isFalse); // missing available -> false
        expect(flags['hasTactilePaving'], isFalse); // explicitly false
        expect(flags['hasAudioSupport'], isTrue); // explicitly true
        expect(flags['hasHearingSupport'], isFalse); // null -> false
      });

      test('should handle empty accessibility map', () {
        final accessibility = <String, dynamic>{};
        
        final flags = computeAccessibilityFlags(accessibility);
        
        expect(flags['hasWheelchairAccess'], isFalse);
        expect(flags['hasAccessibleToilet'], isFalse);
        expect(flags['hasElevator'], isFalse);
        expect(flags['hasAccessibleParking'], isFalse);
        expect(flags['hasTactilePaving'], isFalse);
        expect(flags['hasAudioSupport'], isFalse);
        expect(flags['hasHearingSupport'], isFalse);
      });
    });

    group('isAccessibilityVerified', () {
      test('should return true if at least one feature is verified', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true, 'verified': true},
          'accessibleToilet': {'available': false, 'verified': false},
          'elevator': {'available': false, 'verified': false},
          'accessibleParking': {'available': false, 'verified': false},
          'tactilePaving': {'available': false, 'verified': false},
          'audioSupport': {'available': false, 'verified': false},
          'hearingSupport': {'available': false, 'verified': false},
        };
        
        expect(isAccessibilityVerified(accessibility), isTrue);
      });

      test('should return true if multiple features are verified', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true, 'verified': true},
          'accessibleToilet': {'available': true, 'verified': true},
          'elevator': {'available': false, 'verified': false},
          'accessibleParking': {'available': false, 'verified': false},
          'tactilePaving': {'available': false, 'verified': false},
          'audioSupport': {'available': true, 'verified': true},
          'hearingSupport': {'available': false, 'verified': false},
        };
        
        expect(isAccessibilityVerified(accessibility), isTrue);
      });

      test('should return false if no features are verified', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true, 'verified': false},
          'accessibleToilet': {'available': true, 'verified': false},
          'elevator': {'available': true, 'verified': false},
          'accessibleParking': {'available': true, 'verified': false},
          'tactilePaving': {'available': true, 'verified': false},
          'audioSupport': {'available': true, 'verified': false},
          'hearingSupport': {'available': true, 'verified': false},
        };
        
        expect(isAccessibilityVerified(accessibility), isFalse);
      });

      test('should return false for missing verified keys', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true}, // No verified key
          'accessibleToilet': {'available': true, 'verified': null},
          'elevator': {'available': true},
          'accessibleParking': {'available': true},
          'tactilePaving': {'available': true},
          'audioSupport': {'available': true},
          'hearingSupport': {'available': true},
        };
        
        expect(isAccessibilityVerified(accessibility), isFalse);
      });

      test('should handle null verified values as not verified', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true, 'verified': null},
          'accessibleToilet': null, // Entire feature is null
          'elevator': {'available': true, 'verified': false},
          'accessibleParking': {'available': true}, // Missing verified key
          'tactilePaving': {'available': true, 'verified': false},
          'audioSupport': {'available': true, 'verified': false},
          'hearingSupport': {'available': true, 'verified': false},
        };
        
        expect(isAccessibilityVerified(accessibility), isFalse);
      });

      test('should return false for empty accessibility map', () {
        final accessibility = <String, dynamic>{};
        
        expect(isAccessibilityVerified(accessibility), isFalse);
      });

      test('should work regardless of available status', () {
        final accessibility = {
          'wheelchairAccessible': {'available': false, 'verified': false},
          'accessibleToilet': {'available': false, 'verified': true}, // Verified but not available
          'elevator': {'available': false, 'verified': false},
          'accessibleParking': {'available': false, 'verified': false},
          'tactilePaving': {'available': false, 'verified': false},
          'audioSupport': {'available': false, 'verified': false},
          'hearingSupport': {'available': false, 'verified': false},
        };
        
        // Even though accessible toilet is not available, it's verified, so return true
        expect(isAccessibilityVerified(accessibility), isTrue);
      });
    });
  });
}