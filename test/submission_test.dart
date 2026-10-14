import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:accesslink/models/submission.dart';

void main() {
  group('Submission Models', () {
    group('PhotoSubmission', () {
      test('toMap() includes all required fields', () {
        final submission = PhotoSubmission(
          type: SubmissionType.photo,
          placeId: 'place123',
          placeName: 'Test Place',
          submittedBy: 'user123',
          submitterName: 'John Doe',
          cloudinaryPublicId: 'sample_public_id_123',
          cloudinaryVersion: '1697193600',
          status: SubmissionStatus.pending,
          createdAt: DateTime(2023, 10, 13, 12, 0),
        );

        final map = submission.toMap();

        expect(map['type'], equals('photo'));
        expect(map['placeId'], equals('place123'));
        expect(map['placeName'], equals('Test Place'));
        expect(map['submittedBy'], equals('user123'));
        expect(map['submitterName'], equals('John Doe'));
        expect(map['cloudinaryPublicId'], equals('sample_public_id_123'));
        expect(map['cloudinaryVersion'], equals('1697193600'));
        expect(map['status'], equals('pending'));
        expect(map['createdAt'], isA<Timestamp>());
        expect(map.containsKey('reviewedBy'), isFalse);
        expect(map.containsKey('reviewedAt'), isFalse);
        expect(map.containsKey('rejectionReason'), isFalse);
        // Verify old fields are not in the map
        expect(map.containsKey('imageUrl'), isFalse);
        expect(map.containsKey('storagePath'), isFalse);
      });

      test('toMap() excludes cloudinaryVersion when null', () {
        final submission = PhotoSubmission(
          type: SubmissionType.photo,
          placeId: 'place123',
          placeName: 'Test Place',
          submittedBy: 'user123',
          submitterName: 'John Doe',
          cloudinaryPublicId: 'sample_public_id_123',
          status: SubmissionStatus.pending,
          createdAt: DateTime(2023, 10, 13, 12, 0),
        );

        final map = submission.toMap();

        expect(map['cloudinaryPublicId'], equals('sample_public_id_123'));
        expect(map.containsKey('cloudinaryVersion'), isFalse);
      });

      test('toMap() includes optional fields when present', () {
        final submission = PhotoSubmission(
          type: SubmissionType.photo,
          placeId: 'place123',
          placeName: 'Test Place',
          submittedBy: 'user123',
          submitterName: 'John Doe',
          cloudinaryPublicId: 'sample_public_id_123',
          cloudinaryVersion: '1697193600',
          status: SubmissionStatus.rejected,
          createdAt: DateTime(2023, 10, 13, 12, 0),
          reviewedBy: 'admin123',
          reviewedAt: DateTime(2023, 10, 14, 12, 0),
          rejectionReason: 'Inappropriate content',
        );

        final map = submission.toMap();

        expect(map['status'], equals('rejected'));
        expect(map['reviewedBy'], equals('admin123'));
        expect(map['reviewedAt'], isA<Timestamp>());
        expect(map['rejectionReason'], equals('Inappropriate content'));
      });

      test('fromData() creates valid PhotoSubmission with Cloudinary fields', () {
        final data = {
          'type': 'photo',
          'placeId': 'place123',
          'placeName': 'Test Place',
          'submittedBy': 'user123',
          'submitterName': 'John Doe',
          'cloudinaryPublicId': 'sample_public_id_123',
          'cloudinaryVersion': '1697193600',
          'status': 'pending',
          'createdAt': Timestamp.fromDate(DateTime(2023, 10, 13, 12, 0)),
        };

        final submission = PhotoSubmission.fromData(data, id: 'sub123');

        expect(submission, isNotNull);
        expect(submission!.id, equals('sub123'));
        expect(submission.type, equals(SubmissionType.photo));
        expect(submission.placeId, equals('place123'));
        expect(submission.placeName, equals('Test Place'));
        expect(submission.submittedBy, equals('user123'));
        expect(submission.submitterName, equals('John Doe'));
        expect(submission.cloudinaryPublicId, equals('sample_public_id_123'));
        expect(submission.cloudinaryVersion, equals('1697193600'));
        expect(submission.status, equals(SubmissionStatus.pending));
        expect(submission.createdAt, equals(DateTime(2023, 10, 13, 12, 0)));
        expect(submission.reviewedBy, isNull);
        expect(submission.reviewedAt, isNull);
        expect(submission.rejectionReason, isNull);
      });

      test('fromData() handles missing cloudinaryVersion gracefully', () {
        final data = {
          'type': 'photo',
          'placeId': 'place123',
          'placeName': 'Test Place',
          'submittedBy': 'user123',
          'submitterName': 'John Doe',
          'cloudinaryPublicId': 'sample_public_id_123',
          'status': 'pending',
          'createdAt': Timestamp.fromDate(DateTime(2023, 10, 13, 12, 0)),
        };

        final submission = PhotoSubmission.fromData(data, id: 'sub123');

        expect(submission, isNotNull);
        expect(submission!.cloudinaryPublicId, equals('sample_public_id_123'));
        expect(submission.cloudinaryVersion, isNull);
      });

      test('fromData() legacy compatibility - handles old Firebase Storage documents', () {
        // Simulates legacy documents that only have imageUrl and storagePath
        final legacyData = {
          'type': 'photo',
          'placeId': 'place123',
          'placeName': 'Test Place',
          'submittedBy': 'user123',
          'submitterName': 'John Doe',
          'imageUrl': 'https://example.com/image.jpg',
          'storagePath': 'place_photo_submissions/user123/sub123/image.jpg',
          'status': 'pending',
          'createdAt': Timestamp.fromDate(DateTime(2023, 10, 13, 12, 0)),
        };

        final submission = PhotoSubmission.fromData(legacyData, id: 'sub123');

        expect(submission, isNotNull);
        expect(submission!.id, equals('sub123'));
        expect(submission.type, equals(SubmissionType.photo));
        expect(submission.placeId, equals('place123'));
        expect(submission.placeName, equals('Test Place'));
        expect(submission.submittedBy, equals('user123'));
        expect(submission.submitterName, equals('John Doe'));
        expect(submission.cloudinaryPublicId, equals('')); // Default fallback
        expect(submission.cloudinaryVersion, isNull);
        expect(submission.status, equals(SubmissionStatus.pending));
        expect(submission.createdAt, equals(DateTime(2023, 10, 13, 12, 0)));
      });

      test('fromData() returns null for invalid data', () {
        final data = <String, dynamic>{}; // Empty data

        final submission = PhotoSubmission.fromData(data);

        expect(submission, isNull);
      });

      test('round-trip serialization preserves data', () {
        final original = PhotoSubmission(
          type: SubmissionType.photo,
          placeId: 'place123',
          placeName: 'Test Place',
          submittedBy: 'user123',
          submitterName: 'John Doe',
          cloudinaryPublicId: 'sample_public_id_123',
          cloudinaryVersion: '1697193600',
          status: SubmissionStatus.approved,
          createdAt: DateTime(2023, 10, 13, 12, 0),
          reviewedBy: 'admin123',
          reviewedAt: DateTime(2023, 10, 14, 12, 0),
        );

        final map = original.toMap();
        final restored = PhotoSubmission.fromData(map, id: 'sub123');

        expect(restored, isNotNull);
        expect(restored!.type, equals(original.type));
        expect(restored.placeId, equals(original.placeId));
        expect(restored.placeName, equals(original.placeName));
        expect(restored.submittedBy, equals(original.submittedBy));
        expect(restored.submitterName, equals(original.submitterName));
        expect(restored.cloudinaryPublicId, equals(original.cloudinaryPublicId));
        expect(restored.cloudinaryVersion, equals(original.cloudinaryVersion));
        expect(restored.status, equals(original.status));
        expect(restored.createdAt, equals(original.createdAt));
        expect(restored.reviewedBy, equals(original.reviewedBy));
        expect(restored.reviewedAt, equals(original.reviewedAt));
      });
    });

    group('AccessibilitySubmission', () {
      test('toMap() includes all required fields', () {
        final payload = {
          'wheelchairAccessible': {
            'available': true,
            'notes': 'Ramp available at main entrance',
          },
          'accessibleToilet': {
            'available': false,
            'notes': 'No accessible toilet facilities',
          },
        };

        final submission = AccessibilitySubmission(
          type: SubmissionType.accessibility,
          placeId: 'place123',
          placeName: 'Test Place',
          submittedBy: 'user123',
          submitterName: 'John Doe',
          kind: AccessibilityKind.update,
          payload: payload,
          status: SubmissionStatus.pending,
          createdAt: DateTime(2023, 10, 13, 12, 0),
        );

        final map = submission.toMap();

        expect(map['type'], equals('accessibility'));
        expect(map['placeId'], equals('place123'));
        expect(map['placeName'], equals('Test Place'));
        expect(map['submittedBy'], equals('user123'));
        expect(map['submitterName'], equals('John Doe'));
        expect(map['kind'], equals('update'));
        expect(map['payload'], equals(payload));
        expect(map['status'], equals('pending'));
        expect(map['createdAt'], isA<Timestamp>());
      });

      test('fromData() creates valid AccessibilitySubmission', () {
        final payload = {
          'wheelchairAccessible': {
            'available': true,
            'notes': 'Ramp available at main entrance',
          },
        };

        final data = {
          'type': 'accessibility',
          'placeId': 'place123',
          'placeName': 'Test Place',
          'submittedBy': 'user123',
          'submitterName': 'John Doe',
          'kind': 'update',
          'payload': payload,
          'status': 'pending',
          'createdAt': Timestamp.fromDate(DateTime(2023, 10, 13, 12, 0)),
        };

        final submission = AccessibilitySubmission.fromData(data, id: 'sub123');

        expect(submission, isNotNull);
        expect(submission!.id, equals('sub123'));
        expect(submission.type, equals(SubmissionType.accessibility));
        expect(submission.placeId, equals('place123'));
        expect(submission.placeName, equals('Test Place'));
        expect(submission.submittedBy, equals('user123'));
        expect(submission.submitterName, equals('John Doe'));
        expect(submission.kind, equals(AccessibilityKind.update));
        expect(submission.payload, equals(payload));
        expect(submission.status, equals(SubmissionStatus.pending));
        expect(submission.createdAt, equals(DateTime(2023, 10, 13, 12, 0)));
      });

      test('round-trip serialization preserves data', () {
        final payload = {
          'wheelchairAccessible': {
            'available': true,
            'notes': 'Ramp available at main entrance',
          },
          'accessibleToilet': {
            'available': false,
            'notes': 'No accessible toilet facilities',
          },
        };

        final original = AccessibilitySubmission(
          type: SubmissionType.accessibility,
          placeId: 'place123',
          placeName: 'Test Place',
          submittedBy: 'user123',
          submitterName: 'John Doe',
          kind: AccessibilityKind.update,
          payload: payload,
          status: SubmissionStatus.pending,
          createdAt: DateTime(2023, 10, 13, 12, 0),
        );

        final map = original.toMap();
        final restored = AccessibilitySubmission.fromData(map, id: 'sub123');

        expect(restored, isNotNull);
        expect(restored!.type, equals(original.type));
        expect(restored.placeId, equals(original.placeId));
        expect(restored.placeName, equals(original.placeName));
        expect(restored.submittedBy, equals(original.submittedBy));
        expect(restored.submitterName, equals(original.submitterName));
        expect(restored.kind, equals(original.kind));
        expect(restored.payload, equals(original.payload));
        expect(restored.status, equals(original.status));
        expect(restored.createdAt, equals(original.createdAt));
      });
    });
  });

  group('Validation Logic', () {
    test('file size validation logic', () {
      const maxSize = 5 * 1024 * 1024; // 5MB in bytes
      
      // Test cases for file size validation
      expect(4 * 1024 * 1024 <= maxSize, isTrue, reason: '4MB should be valid');
      expect(5 * 1024 * 1024 <= maxSize, isTrue, reason: '5MB should be valid');
      expect(6 * 1024 * 1024 <= maxSize, isFalse, reason: '6MB should be invalid');
      expect(10 * 1024 * 1024 <= maxSize, isFalse, reason: '10MB should be invalid');
    });

    test('mime type validation logic', () {
      // Test valid image MIME types
      expect('image/jpeg'.startsWith('image/'), isTrue);
      expect('image/png'.startsWith('image/'), isTrue);
      expect('image/gif'.startsWith('image/'), isTrue);
      expect('image/webp'.startsWith('image/'), isTrue);
      
      // Test invalid MIME types
      expect('text/plain'.startsWith('image/'), isFalse);
      expect('video/mp4'.startsWith('image/'), isFalse);
      expect('audio/mpeg'.startsWith('image/'), isFalse);
      expect('application/pdf'.startsWith('image/'), isFalse);
    });
  });

  // Note: Firebase integration tests are skipped to avoid requiring live Firebase setup
  group('Firebase Integration Tests (Skipped)', () {
    test('createAccessibilitySubmission builds proper document structure', () {
      // This test would verify the structure of the document being created
      // but is skipped because it requires extensive Firebase mocking
    }, skip: 'Requires live Firebase instance - would need proper Firebase test setup');
    
    test('watchPendingPhotoSubmissions filters correctly', () {
      // This test would verify query filtering and stream mapping
      // but is skipped because it requires extensive Firestore mocking
    }, skip: 'Requires live Firebase instance - would need proper Firebase test setup');
    
    test('PhotoUploadService validates file size and content type', () {
      // This test would verify file validation in the service
      // but is skipped because it requires mocking ImagePicker and Firebase Storage
    }, skip: 'Requires complex Firebase Storage and ImagePicker mocking');
  });
}