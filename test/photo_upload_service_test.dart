import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:accesslink/services/photo_upload_service.dart';
import 'package:accesslink/services/cloudinary_client.dart';

/// Mock Firebase User for testing
class MockUser extends Fake implements User {
  final String _uid;
  final String? _displayName;
  final String? _email;
  
  MockUser({
    required String uid,
    String? displayName,
    String? email,
  }) : _uid = uid, _displayName = displayName, _email = email;
  
  @override
  String get uid => _uid;
  
  @override
  String? get displayName => _displayName;
  
  @override
  String? get email => _email;
}

/// Mock Firebase Auth for testing
class MockFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _currentUser;
  
  MockFirebaseAuth({User? currentUser}) : _currentUser = currentUser;
  
  @override
  User? get currentUser => _currentUser;
}

/// Mock ImagePicker for testing
class MockImagePicker extends Fake implements ImagePicker {
  final XFile? _mockFile;
  
  MockImagePicker({XFile? mockFile}) : _mockFile = mockFile;
  
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return _mockFile;
  }
}

/// Mock CloudinaryClient for testing
class MockCloudinaryClient extends Fake implements CloudinaryClient {
  final Map<String, dynamic>? _mockSignedParams;
  final CloudinaryUploadResult? _mockUploadResult;
  final Exception? _signException;
  final Exception? _uploadException;
  
  MockCloudinaryClient({
    Map<String, dynamic>? mockSignedParams,
    CloudinaryUploadResult? mockUploadResult,
    Exception? signException,
    Exception? uploadException,
  }) : _mockSignedParams = mockSignedParams,
       _mockUploadResult = mockUploadResult,
       _signException = signException,
       _uploadException = uploadException;
  
  @override
  Future<Map<String, dynamic>> getUploadSignature({
    required String submissionId,
  }) async {
    if (_signException != null) throw _signException;
    return _mockSignedParams ?? {
      'signature': 'test-signature',
      'timestamp': 1234567890,
      'api_key': 'test-api-key',
      'folder': 'test-folder',
      'public_id': 'test-public-id-$submissionId',
      'type': 'authenticated',
    };
  }
  
  @override
  Future<CloudinaryUploadResult> uploadToCloudinary({
    required Uint8List fileBytes,
    required String fileName,
    required String contentType,
    required Map<String, dynamic> signedParams,
  }) async {
    if (_uploadException != null) throw _uploadException;
    return _mockUploadResult ?? CloudinaryUploadResult(
      publicId: signedParams['public_id'] ?? 'test-public-id',
      version: 123456789,
    );
  }
}

/// Helper to create a test file that passes validation
File createTestImageFile() {
  // Create a temporary file with valid image content
  final tempDir = Directory.systemTemp;
  final testFile = File('${tempDir.path}/test_image.jpg');
  
  // Write a minimal JPEG header to pass MIME type validation
  // This is a minimal valid JPEG file that's small enough for tests
  final jpegHeader = [
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
    0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
    0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
    0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
    0xFF, 0xC4, 0x00, 0x15, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0xFF, 0xC4,
    0x00, 0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x0C,
    0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3F, 0x00, 0x00, 0xFF, 0xD9
  ];
  
  testFile.writeAsBytesSync(jpegHeader);
  return testFile;
}

/// Helper to create a test file that's too large (>5MB)
File createLargeTestFile() {
  final tempDir = Directory.systemTemp;
  final testFile = File('${tempDir.path}/large_test_file.jpg');
  
  // Create a file larger than 5MB
  final largeContent = List.filled(6 * 1024 * 1024, 0xFF);
  testFile.writeAsBytesSync(largeContent);
  return testFile;
}

/// Helper to create a test file with invalid MIME type
File createNonImageFile() {
  final tempDir = Directory.systemTemp;
  final testFile = File('${tempDir.path}/test_file.txt');
  testFile.writeAsStringSync('This is not an image file');
  return testFile;
}

/// Simple Mock Firestore for testing
class MockFirebaseFirestore extends Fake implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> _documents = {};
  String _lastDocId = '';
  
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return MockCollectionReference(this, path);
  }
}

class MockCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  final MockFirebaseFirestore _firestore;
  final String _path;
  
  MockCollectionReference(this._firestore, this._path);
  
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final docId = path ?? 'mock-doc-${DateTime.now().millisecondsSinceEpoch}';
    _firestore._lastDocId = docId;
    return MockDocumentReference(_firestore, '$_path/$docId', docId);
  }
}

class MockDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {
  final MockFirebaseFirestore _firestore;
  final String _path;
  final String _id;
  
  MockDocumentReference(this._firestore, this._path, this._id);
  
  @override
  String get id => _id;
  
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _firestore._documents[_path] = data;
  }
}

void main() {
  group('PhotoUploadService', () {
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late PhotoUploadService service;

    const testUserId = 'test-user-123';
    const testDisplayName = 'Test User';
    const testEmail = 'test@example.com';
    const testPlaceId = 'place-123';
    const testPlaceName = 'Test Place';

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockUser = MockUser(
        uid: testUserId,
        displayName: testDisplayName,
        email: testEmail,
      );
      mockAuth = MockFirebaseAuth(currentUser: mockUser);
    });

    group('Authentication Guards', () {
      test('should throw StateError when user is not logged in', () async {
        final unauthenticatedAuth = MockFirebaseAuth(currentUser: null);
        service = PhotoUploadService(
          auth: unauthenticatedAuth,
          firestore: mockFirestore,
          cloudinaryClient: MockCloudinaryClient(),
          imagePicker: MockImagePicker(),
        );

        await expectLater(
          () => service.pickAndSubmitPhoto(
            placeId: testPlaceId,
            placeName: testPlaceName,
          ),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', 'Please log in to submit a photo.')),
        );
      });
    });

    group('Image Picker Integration', () {
      test('should return null when user cancels image selection', () async {
        service = PhotoUploadService(
          auth: mockAuth,
          firestore: mockFirestore,
          cloudinaryClient: MockCloudinaryClient(),
          imagePicker: MockImagePicker(mockFile: null), // User cancelled
        );

        final result = await service.pickAndSubmitPhoto(
          placeId: testPlaceId,
          placeName: testPlaceName,
        );

        expect(result, isNull);
      });

      // Note: Full image picker testing with actual file I/O requires device testing
      // and is skipped here as per instructions to avoid fake-passing device-dependent tests
    });

    group('File Validation', () {
      test('should reject files larger than 5MB', () async {
        final largeFile = createLargeTestFile();
        final mockPicker = MockImagePicker(
          mockFile: XFile(largeFile.path),
        );

        service = PhotoUploadService(
          auth: mockAuth,
          firestore: mockFirestore,
          cloudinaryClient: MockCloudinaryClient(),
          imagePicker: mockPicker,
        );

        await expectLater(
          () => service.pickAndSubmitPhoto(
            placeId: testPlaceId,
            placeName: testPlaceName,
          ),
          throwsA(isA<ArgumentError>()
              .having((e) => e.message, 'message', 
                contains('Image too large. Please select an image smaller than 5MB.'))),
        );

        // Cleanup
        largeFile.deleteSync();
      });

      test('should reject non-image files', () async {
        final nonImageFile = createNonImageFile();
        final mockPicker = MockImagePicker(
          mockFile: XFile(nonImageFile.path),
        );

        service = PhotoUploadService(
          auth: mockAuth,
          firestore: mockFirestore,
          cloudinaryClient: MockCloudinaryClient(),
          imagePicker: mockPicker,
        );

        await expectLater(
          () => service.pickAndSubmitPhoto(
            placeId: testPlaceId,
            placeName: testPlaceName,
          ),
          throwsA(isA<ArgumentError>()
              .having((e) => e.message, 'message',
                contains('Invalid file type. Please select an image file.'))),
        );

        // Cleanup
        nonImageFile.deleteSync();
      });

      test('should accept valid image files under 5MB', () async {
        final validFile = createTestImageFile();
        final mockPicker = MockImagePicker(
          mockFile: XFile(validFile.path),
        );

        final mockCloudinaryClient = MockCloudinaryClient(
          mockUploadResult: const CloudinaryUploadResult(
            publicId: 'test-public-id',
            version: 123456789,
          ),
        );

        service = PhotoUploadService(
          auth: mockAuth,
          firestore: mockFirestore,
          cloudinaryClient: mockCloudinaryClient,
          imagePicker: mockPicker,
        );

        final result = await service.pickAndSubmitPhoto(
          placeId: testPlaceId,
          placeName: testPlaceName,
        );

        expect(result, isNotNull);
        expect(result, isA<String>());

        // Cleanup
        validFile.deleteSync();
      });
    });

    group('Cloudinary Integration', () {
      test('should successfully complete upload workflow with Cloudinary integration', () async {
        final validFile = createTestImageFile();
        final mockPicker = MockImagePicker(
          mockFile: XFile(validFile.path),
        );

        const expectedPublicId = 'test-cloudinary-public-id';
        const expectedVersion = 987654321;

        final mockCloudinaryClient = MockCloudinaryClient(
          mockUploadResult: const CloudinaryUploadResult(
            publicId: expectedPublicId,
            version: expectedVersion,
          ),
        );

        service = PhotoUploadService(
          auth: mockAuth,
          firestore: mockFirestore,
          cloudinaryClient: mockCloudinaryClient,
          imagePicker: mockPicker,
        );

        final submissionId = await service.pickAndSubmitPhoto(
          placeId: testPlaceId,
          placeName: testPlaceName,
        );

        expect(submissionId, isNotNull);
        expect(submissionId, isA<String>());

        // Verify that the mock Firestore received the document with expected Cloudinary fields
        final documentPath = 'contributions/${mockFirestore._lastDocId}';
        expect(mockFirestore._documents.containsKey(documentPath), isTrue);
        
        final savedData = mockFirestore._documents[documentPath]!;
        expect(savedData['cloudinaryPublicId'], equals(expectedPublicId));
        expect(savedData['cloudinaryVersion'], equals(expectedVersion.toString()));
        expect(savedData['status'], equals('pending'));
        expect(savedData['submittedBy'], equals(testUserId));
        expect(savedData['submitterName'], equals(testDisplayName));
        expect(savedData['placeId'], equals(testPlaceId));
        expect(savedData['placeName'], equals(testPlaceName));

        // Cleanup
        validFile.deleteSync();
      });

      test('should handle CloudinaryException during signature request', () async {
        final validFile = createTestImageFile();
        final mockPicker = MockImagePicker(
          mockFile: XFile(validFile.path),
        );

        final mockCloudinaryClient = MockCloudinaryClient(
          signException: const CloudinaryException('Sign failed', code: 'SIGN_ERROR'),
        );

        service = PhotoUploadService(
          auth: mockAuth,
          firestore: mockFirestore,
          cloudinaryClient: mockCloudinaryClient,
          imagePicker: mockPicker,
        );

        await expectLater(
          () => service.pickAndSubmitPhoto(
            placeId: testPlaceId,
            placeName: testPlaceName,
          ),
          throwsA(isA<CloudinaryException>()
              .having((e) => e.message, 'message', 'Sign failed')
              .having((e) => e.code, 'code', 'SIGN_ERROR')),
        );

        // Cleanup
        validFile.deleteSync();
      });

      test('should handle CloudinaryException during upload', () async {
        final validFile = createTestImageFile();
        final mockPicker = MockImagePicker(
          mockFile: XFile(validFile.path),
        );

        final mockCloudinaryClient = MockCloudinaryClient(
          uploadException: const CloudinaryException('Upload failed', code: 'UPLOAD_ERROR'),
        );

        service = PhotoUploadService(
          auth: mockAuth,
          firestore: mockFirestore,
          cloudinaryClient: mockCloudinaryClient,
          imagePicker: mockPicker,
        );

        await expectLater(
          () => service.pickAndSubmitPhoto(
            placeId: testPlaceId,
            placeName: testPlaceName,
          ),
          throwsA(isA<CloudinaryException>()
              .having((e) => e.message, 'message', 'Upload failed')
              .having((e) => e.code, 'code', 'UPLOAD_ERROR')),
        );

        // Cleanup
        validFile.deleteSync();
      });
    });

    group('Error Propagation', () {
      test('should rethrow CloudinaryException from getUploadSignature', () async {
        final validFile = createTestImageFile();
        final mockPicker = MockImagePicker(
          mockFile: XFile(validFile.path),
        );

        final expectedException = const CloudinaryException(
          'Cloudinary upload failed (401): Invalid Signature', 
          code: '401',
        );
        
        final mockCloudinaryClient = MockCloudinaryClient(
          signException: expectedException,
        );

        service = PhotoUploadService(
          auth: mockAuth,
          firestore: mockFirestore,
          cloudinaryClient: mockCloudinaryClient,
          imagePicker: mockPicker,
        );

        await expectLater(
          () => service.pickAndSubmitPhoto(
            placeId: testPlaceId,
            placeName: testPlaceName,
          ),
          throwsA(isA<CloudinaryException>()
              .having((e) => e.message, 'message', contains('Invalid Signature'))
              .having((e) => e.code, 'code', '401')),
        );

        // Cleanup
        validFile.deleteSync();
      });

      test('should rethrow CloudinaryException from uploadToCloudinary', () async {
        final validFile = createTestImageFile();
        final mockPicker = MockImagePicker(
          mockFile: XFile(validFile.path),
        );

        final expectedException = const CloudinaryException(
          'Cloudinary upload failed (401): Invalid Signature', 
          code: '401',
        );

        final mockCloudinaryClient = MockCloudinaryClient(
          uploadException: expectedException,
        );

        service = PhotoUploadService(
          auth: mockAuth,
          firestore: mockFirestore,
          cloudinaryClient: mockCloudinaryClient,
          imagePicker: mockPicker,
        );

        await expectLater(
          () => service.pickAndSubmitPhoto(
            placeId: testPlaceId,
            placeName: testPlaceName,
          ),
          throwsA(isA<CloudinaryException>()
              .having((e) => e.message, 'message', contains('Invalid Signature'))
              .having((e) => e.code, 'code', '401')),
        );

        // Cleanup
        validFile.deleteSync();
      });
    });

    group('Error Handling', () {
      test('should rethrow Firestore errors after successful Cloudinary upload', () async {
        final validFile = createTestImageFile();
        final mockPicker = MockImagePicker(
          mockFile: XFile(validFile.path),
        );

        final mockCloudinaryClient = MockCloudinaryClient(
          mockUploadResult: const CloudinaryUploadResult(
            publicId: 'test-public-id',
            version: 123456789,
          ),
        );

        // Create a mock Firestore that throws on set operations
        final failingFirestore = FailingMockFirebaseFirestore();
        
        service = PhotoUploadService(
          auth: mockAuth,
          firestore: failingFirestore,
          cloudinaryClient: mockCloudinaryClient,
          imagePicker: mockPicker,
        );

        await expectLater(
          () => service.pickAndSubmitPhoto(
            placeId: testPlaceId,
            placeName: testPlaceName,
          ),
          throwsA(isA<Exception>()
              .having((e) => e.toString(), 'toString', contains('Firestore write failed'))),
        );

        // Cleanup
        validFile.deleteSync();
      });
    });
  });
}

/// Mock Firestore that fails on set operations to test error handling
class FailingMockFirebaseFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return FailingMockCollectionReference();
  }
}

class FailingMockCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FailingMockDocumentReference();
  }
}

class FailingMockDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {
  @override
  String get id => 'mock-doc-id';
  
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) {
    throw Exception('Firestore write failed - simulated error');
  }
}