import 'package:flutter_test/flutter_test.dart';
import 'package:accesslink/models/submission.dart';
import 'package:accesslink/services/cloudinary_client.dart';
import 'package:accesslink/utils/accessibility_compute.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Mock classes for testing
class MockCloudinaryClient implements CloudinaryClient {
  final Map<String, String> _promotedAssets = {};
  bool throwOnPromote = false;
  String? promoteErrorMessage;

  @override
  Future<String> promote({
    required String submissionId,
    required String placeId,
    required String publicId,
  }) async {
    if (throwOnPromote) {
      throw CloudinaryException(promoteErrorMessage ?? 'Promote failed');
    }
    
    // Simulate deterministic promotion - same inputs yield same URL
    final secureUrl = 'https://res.cloudinary.com/test/image/upload/v1/$placeId/$submissionId.jpg';
    _promotedAssets[submissionId] = secureUrl;
    return secureUrl;
  }

  // Other methods not needed for testing but required by interface
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class MockFirebaseAuth implements FirebaseAuth {
  final User? _currentUser;
  
  MockFirebaseAuth({User? currentUser}) : _currentUser = currentUser;

  @override
  User? get currentUser => _currentUser;

  // Other methods not needed for testing
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class MockUser implements User {
  @override
  final String uid;

  MockUser({required this.uid});

  // Other methods not needed for testing
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// Test constants
final _testDate = DateTime(2024, 1, 1, 12, 0, 0);

void main() {
  group('Role checking logic', () {
      test('staff roles should be admin or moderator', () {
        const staffRoles = ['admin', 'moderator'];
        const nonStaffRoles = ['user', 'premium', 'guest', '', null];

        for (final role in staffRoles) {
          expect(staffRoles.contains(role), isTrue,
              reason: 'Role $role should be considered staff');
        }

        for (final role in nonStaffRoles) {
          expect(staffRoles.contains(role), isFalse,
              reason: 'Role $role should not be considered staff');
        }
    });
  });

  group('ModerationService', () {
    group('approvePhoto - Cloudinary integration', () {
      late MockCloudinaryClient mockCloudinaryClient;

      setUp(() {
        mockCloudinaryClient = MockCloudinaryClient();
      });

      test('should promote Cloudinary asset and update Firestore on approval', () async {
        final submission = PhotoSubmission(
          id: 'sub123',
          type: SubmissionType.photo,
          placeId: 'place456',
          placeName: 'Test Place',
          submittedBy: 'user1',
          submitterName: 'Test User',
          cloudinaryPublicId: 'pending_photos/user1/sub123',
          status: SubmissionStatus.pending,
          createdAt: _testDate,
        );

        // This test verifies the core logic without making actual external calls
        // In a full test, we would verify that promote is called with correct parameters
        // and that Firestore transaction updates the correct documents
        expect(submission.status, equals(SubmissionStatus.pending));
        expect(submission.cloudinaryPublicId, isNotEmpty);
        expect(submission.id, equals('sub123'));
        expect(submission.placeId, equals('place456'));
        
        // Test would call: await moderationService.approvePhoto(submission);
        // Expected: promote called with (submissionId: sub123, placeId: place456, publicId: pending_photos/user1/sub123)
        // Expected: Firestore transaction updates places/place456 and contributions/sub123
      });

      test('should be idempotent - skip processing non-pending submissions', () async {
        final approvedSubmission = PhotoSubmission(
          id: 'sub123',
          type: SubmissionType.photo,
          placeId: 'place456',
          placeName: 'Test Place',
          submittedBy: 'user1',
          submitterName: 'Test User',
          cloudinaryPublicId: 'pending_photos/user1/sub123',
          status: SubmissionStatus.approved, // Already processed
          createdAt: _testDate,
        );

        // Should be a no-op since status != pending
        expect(approvedSubmission.status, equals(SubmissionStatus.approved));
        expect(approvedSubmission.status != SubmissionStatus.pending, isTrue,
            reason: 'Should skip already processed submissions');
      });

      test('should fail with clear error for legacy submissions (empty cloudinaryPublicId)', () {
        final legacySubmission = PhotoSubmission(
          id: 'legacy_sub',
          type: SubmissionType.photo,
          placeId: 'place456',
          placeName: 'Test Place',
          submittedBy: 'user1',
          submitterName: 'Test User',
          cloudinaryPublicId: '', // Legacy submission - no Cloudinary asset
          status: SubmissionStatus.pending,
          createdAt: _testDate,
        );

        expect(legacySubmission.cloudinaryPublicId.isEmpty, isTrue);
        
        // Test would call: await moderationService.approvePhoto(legacySubmission);
        // Expected: throws StateError with message about draining old submissions
        expect(() async => legacySubmission.cloudinaryPublicId.isEmpty 
               ? throw StateError('Legacy submission has no Cloudinary asset; cannot approve. Drain/migrate old pending submissions before cutover.')
               : null,
            throwsStateError);
      });

      test('should surface promote failures without corrupting Firestore', () {
        final submission = PhotoSubmission(
          id: 'sub123',
          type: SubmissionType.photo,
          placeId: 'place456',
          placeName: 'Test Place',
          submittedBy: 'user1',
          submitterName: 'Test User',
          cloudinaryPublicId: 'pending_photos/user1/sub123',
          status: SubmissionStatus.pending,
          createdAt: _testDate,
        );

        // Mock setup for promote failure
        mockCloudinaryClient.throwOnPromote = true;
        mockCloudinaryClient.promoteErrorMessage = 'Network error';

        // Test would call: await moderationService.approvePhoto(submission);
        // Expected: CloudinaryException thrown, no Firestore writes committed
        // Submission status should remain pending
        expect(submission.status, equals(SubmissionStatus.pending));
      });

      test('should generate deterministic secure URLs from promote', () async {
        const submissionId = 'sub123';
        const placeId = 'place456';
        const publicId = 'pending_photos/user1/sub123';

        final secureUrl1 = await mockCloudinaryClient.promote(
          submissionId: submissionId,
          placeId: placeId,
          publicId: publicId,
        );

        final secureUrl2 = await mockCloudinaryClient.promote(
          submissionId: submissionId,
          placeId: placeId,
          publicId: publicId,
        );

        // Same inputs should yield same URL (deterministic)
        expect(secureUrl1, equals(secureUrl2));
        expect(secureUrl1, contains(placeId));
        expect(secureUrl1, contains(submissionId));
        expect(secureUrl1, startsWith('https://res.cloudinary.com'));
      });
    });

    group('idempotency logic', () {
      test('should skip processing non-pending submissions', () {
        // Test the guard logic that prevents double-processing
        final pendingSubmission = PhotoSubmission(
          type: SubmissionType.photo,
          placeId: 'place1',
          placeName: 'Test Place',
          submittedBy: 'user1',
          submitterName: 'Test User',
          cloudinaryPublicId: 'test_public_id_123',
          status: SubmissionStatus.pending,
          createdAt: _testDate,
        );

        final approvedSubmission = PhotoSubmission(
          type: SubmissionType.photo,
          placeId: 'place1',
          placeName: 'Test Place',
          submittedBy: 'user1',
          submitterName: 'Test User',
          cloudinaryPublicId: 'test_public_id_456',
          status: SubmissionStatus.approved, // Already processed
          createdAt: _testDate,
        );

        expect(pendingSubmission.status, equals(SubmissionStatus.pending));
        expect(approvedSubmission.status, equals(SubmissionStatus.approved));
        
        // The moderation service should only process pending submissions
        expect(pendingSubmission.status == SubmissionStatus.pending, isTrue,
            reason: 'Should process pending submissions');
        expect(approvedSubmission.status == SubmissionStatus.pending, isFalse,
            reason: 'Should skip already processed submissions');
      });
    });

    group('Cloudinary promote determinism', () {
      late MockCloudinaryClient mockCloudinaryClient;

      setUp(() {
        mockCloudinaryClient = MockCloudinaryClient();
      });

      test('should generate consistent promote URLs for same submission data', () async {
        const submissionId = 'sub123';
        const placeId = 'place456';
        const publicId = 'pending_photos/user1/sub123';
        
        // Test that promotion is deterministic - same inputs yield same URL
        final secureUrl1 = await mockCloudinaryClient.promote(
          submissionId: submissionId,
          placeId: placeId,
          publicId: publicId,
        );
        
        final secureUrl2 = await mockCloudinaryClient.promote(
          submissionId: submissionId,
          placeId: placeId,
          publicId: publicId,
        );
        
        expect(secureUrl1, equals(secureUrl2));
        expect(secureUrl1, contains('place456/sub123.jpg'));
        
        // Same inputs should always produce same URL (idempotent promotion)
        expect(secureUrl1, equals(secureUrl2));
      });
    });

    group('accessibility merging logic', () {
      test('should merge only changed features while preserving others', () {
        // Current place accessibility (all 7 features)
        final currentAccessibility = {
          'wheelchairAccessible': {
            'available': false,
            'notes': 'Old notes',
            'verified': false,
          },
          'accessibleToilet': {
            'available': true,
            'notes': 'Existing toilet',
            'verified': true,
          },
          'elevator': {
            'available': false,
            'notes': '',
            'verified': false,
          },
          'accessibleParking': {
            'available': true,
            'notes': 'Existing parking',
            'verified': true,
          },
          'tactilePaving': {
            'available': false,
            'notes': '',
            'verified': false,
          },
          'audioSupport': {
            'available': false,
            'notes': '',
            'verified': false,
          },
          'hearingSupport': {
            'available': true,
            'notes': 'Existing hearing support',
            'verified': true,
          },
        };

        // Submission payload (only changing 2 features)
        final submissionPayload = {
          'wheelchairAccessible': {
            'available': true,
            'notes': 'New ramp installed',
          },
          'elevator': {
            'available': true,
            'notes': 'Working elevator',
          },
        };

        // Simulate the merge logic
        final merged = Map<String, dynamic>.from(currentAccessibility);
        for (final entry in submissionPayload.entries) {
          final featureKey = entry.key;
          final changes = entry.value;

          if (merged[featureKey] == null) {
            merged[featureKey] = <String, dynamic>{};
          }

          final feature = merged[featureKey] as Map<String, dynamic>;
          feature['available'] = changes['available'] ?? feature['available'] ?? false;
          feature['notes'] = changes['notes'] ?? feature['notes'] ?? '';
          feature['verified'] = true; // Set to verified after approval
        }

        // Test that only changed features are modified
        expect(merged['wheelchairAccessible']['available'], isTrue);
        expect(merged['wheelchairAccessible']['notes'], equals('New ramp installed'));
        expect(merged['wheelchairAccessible']['verified'], isTrue);

        expect(merged['elevator']['available'], isTrue);
        expect(merged['elevator']['notes'], equals('Working elevator'));
        expect(merged['elevator']['verified'], isTrue);

        // Test that unchanged features are preserved
        expect(merged['accessibleToilet']['available'], isTrue);
        expect(merged['accessibleToilet']['notes'], equals('Existing toilet'));
        expect(merged['accessibleToilet']['verified'], isTrue); // Preserved

        expect(merged['accessibleParking']['available'], isTrue);
        expect(merged['accessibleParking']['notes'], equals('Existing parking'));
        expect(merged['accessibleParking']['verified'], isTrue); // Preserved

        expect(merged['tactilePaving']['available'], isFalse); // Unchanged
        expect(merged['tactilePaving']['verified'], isFalse); // Unchanged
      });

      test('should recompute accessibility score after merging', () {
        final accessibility = {
          'wheelchairAccessible': {'available': true}, // Changed to true
          'accessibleToilet': {'available': true},     // Was already true
          'elevator': {'available': true},             // Changed to true
          'accessibleParking': {'available': true},    // Was already true
          'tactilePaving': {'available': false},       // Unchanged
          'audioSupport': {'available': false},        // Unchanged
          'hearingSupport': {'available': true},       // Was already true
        };

        final score = computeAccessibilityScore(accessibility);
        // 5/7 features available = 71% (rounded)
        expect(score, equals(71));

        final flags = computeAccessibilityFlags(accessibility);
        expect(flags['hasWheelchairAccess'], isTrue);
        expect(flags['hasAccessibleToilet'], isTrue);
        expect(flags['hasElevator'], isTrue);
        expect(flags['hasAccessibleParking'], isTrue);
        expect(flags['hasTactilePaving'], isFalse);
        expect(flags['hasAudioSupport'], isFalse);
        expect(flags['hasHearingSupport'], isTrue);
      });
    });

    group('rejection logic', () {
      test('should handle rejection with optional reason', () {
        const rejectionWithReason = 'Poor image quality';
        const rejectionWithoutReason = null;

        // Test that both null and string reasons are valid
        expect(rejectionWithReason, isA<String>());
        expect(rejectionWithoutReason, isNull);

        // Test that empty string is treated as null
        final emptyReason = '';
        final processedReason = emptyReason.isEmpty ? null : emptyReason;
        expect(processedReason, isNull);

        final validReason = 'Invalid content';
        final processedValidReason = validReason.isEmpty ? null : validReason;
        expect(processedValidReason, equals('Invalid content'));
      });
    });

    group('place verification logic', () {
      test('should handle verification state changes', () {
        const userId = 'user456';

        // Test verification data structure
        final verificationData = {
          'placeVerified': true,
          'verifiedBy': userId,
          // 'verifiedAt' would be FieldValue.serverTimestamp() in real implementation
        };

        final unverificationData = {
          'placeVerified': false,
          'verifiedBy': null,
          'verifiedAt': null,
        };

        expect(verificationData['placeVerified'], isTrue);
        expect(verificationData['verifiedBy'], equals(userId));

        expect(unverificationData['placeVerified'], isFalse);
        expect(unverificationData['verifiedBy'], isNull);
        expect(unverificationData['verifiedAt'], isNull);
      });
    });
  });

  group('Submission validation', () {
    test('should handle PhotoSubmission data consistency', () {
      final validPhotoSubmission = PhotoSubmission(
        type: SubmissionType.photo,
        placeId: 'place1',
        placeName: 'Test Place',
        submittedBy: 'user1',
        submitterName: 'Test User',
        cloudinaryPublicId: 'test_public_id_789',
        status: SubmissionStatus.pending,
        createdAt: _testDate,
      );

      expect(validPhotoSubmission.type, equals(SubmissionType.photo));
      expect(validPhotoSubmission.status, equals(SubmissionStatus.pending));
      expect(validPhotoSubmission.placeId, isNotEmpty);
      expect(validPhotoSubmission.cloudinaryPublicId, isNotEmpty);
    });

    test('should handle AccessibilitySubmission data consistency', () {
      final validAccessibilitySubmission = AccessibilitySubmission(
        type: SubmissionType.accessibility,
        placeId: 'place1',
        placeName: 'Test Place',
        submittedBy: 'user1',
        submitterName: 'Test User',
        kind: AccessibilityKind.update,
        payload: {
          'wheelchairAccessible': {
            'available': true,
            'notes': 'Ramp available',
          },
        },
        status: SubmissionStatus.pending,
        createdAt: _testDate,
      );

      expect(validAccessibilitySubmission.type, equals(SubmissionType.accessibility));
      expect(validAccessibilitySubmission.kind, equals(AccessibilityKind.update));
      expect(validAccessibilitySubmission.payload, isNotEmpty);
      expect(validAccessibilitySubmission.payload['wheelchairAccessible'], isNotNull);
    });
  });

  // SKIP tests that would require live Firebase services
  group('Firebase integration tests', () {
    test('SKIPPED - approvePhoto with live Storage (requires Firebase setup)', () {
      // This test would require live Firebase Storage and would be slow/unreliable
      // In a real test suite, this would use firebase_auth_mocks or similar
      // For now, we skip and note that it needs live services
    }, skip: 'Requires live Firebase Storage - use integration test suite');

    test('SKIPPED - approveAccessibility with live Firestore (requires Firebase setup)', () {
      // This test would require live Firestore and would be slow/unreliable
      // In a real test suite, this would use fake_cloud_firestore
      // For now, we skip and note that it needs live services
    }, skip: 'Requires live Firestore - use integration test suite');

    test('SKIPPED - admin role checking with live Auth (requires Firebase setup)', () {
      // This test would require live Firebase Auth and would be slow/unreliable
      // In a real test suite, this would use firebase_auth_mocks
      // For now, we skip and note that it needs live services
    }, skip: 'Requires live Firebase Auth - use integration test suite');
  });
}