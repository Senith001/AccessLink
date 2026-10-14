import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:accesslink/services/cloudinary_client.dart';

/// Mock Firebase User for testing
class MockUser extends Fake implements User {
  final String? _idToken;
  
  MockUser({this._idToken});
  
  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    if (_idToken == null) throw Exception('No token available');
    return _idToken;
  }
}

/// Mock Firebase Auth for testing
class MockFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _currentUser;
  
  MockFirebaseAuth({this._currentUser});
  
  @override
  User? get currentUser => _currentUser;
}

void main() {
  group('CloudinaryClient', () {
    const testCloudName = 'test-cloud';
    const testSignerBaseUrl = 'https://test-signer.com';
    const testIdToken = 'test-id-token';
    const testSubmissionId = 'test-submission-id';
    const testPublicId = 'test-public-id';
    const testPlaceId = 'test-place-id';

    late MockClient mockHttpClient;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late CloudinaryClient client;

    setUp(() {
      mockHttpClient = MockClient((request) async {
        return http.Response('Not implemented', 404);
      });
      mockUser = MockUser(idToken: testIdToken);
      mockAuth = MockFirebaseAuth(currentUser: mockUser);
      client = CloudinaryClient(
        httpClient: mockHttpClient,
        auth: mockAuth,
        cloudName: testCloudName,
        signerBaseUrl: testSignerBaseUrl,
      );
    });

    group('getUploadSignature', () {
      test('should make correct POST request and return signed params', () async {
        final expectedResponse = {
          'signature': 'test-signature',
          'timestamp': 1234567890,
          'api_key': 'test-api-key',
          'folder': 'test-folder',
          'public_id': 'test-public-id',
          'type': 'authenticated',
        };

        mockHttpClient = MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(request.url.toString(), equals('$testSignerBaseUrl/sign-upload'));
          expect(request.headers['Authorization'], equals('Bearer $testIdToken'));
          expect(request.headers['Content-Type'], equals('application/json'));
          
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['submissionId'], equals(testSubmissionId));
          
          return http.Response(jsonEncode(expectedResponse), 200);
        });

        client = CloudinaryClient(
          httpClient: mockHttpClient,
          auth: mockAuth,
          cloudName: testCloudName,
          signerBaseUrl: testSignerBaseUrl,
        );

        final result = await client.getUploadSignature(submissionId: testSubmissionId);
        expect(result, equals(expectedResponse));
      });

      test('should throw CloudinaryException on non-200 response', () async {
        final errorResponse = {
          'error': 'Invalid submission ID',
          'code': 'INVALID_SUBMISSION',
        };

        mockHttpClient = MockClient((request) async {
          return http.Response(jsonEncode(errorResponse), 400);
        });

        client = CloudinaryClient(
          httpClient: mockHttpClient,
          auth: mockAuth,
          cloudName: testCloudName,
          signerBaseUrl: testSignerBaseUrl,
        );

        await expectLater(
          () => client.getUploadSignature(submissionId: testSubmissionId),
          throwsA(isA<CloudinaryException>()
              .having((e) => e.message, 'message', 'Invalid submission ID')
              .having((e) => e.code, 'code', 'INVALID_SUBMISSION')),
        );
      });

      test('should throw StateError when user is not authenticated', () async {
        final unauthenticatedAuth = MockFirebaseAuth(currentUser: null);
        client = CloudinaryClient(
          httpClient: mockHttpClient,
          auth: unauthenticatedAuth,
          cloudName: testCloudName,
          signerBaseUrl: testSignerBaseUrl,
        );

        await expectLater(
          () => client.getUploadSignature(submissionId: testSubmissionId),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', contains('User must be authenticated'))),
        );
      });

      test('should throw StateError when not configured', () async {
        client = CloudinaryClient(
          httpClient: mockHttpClient,
          auth: mockAuth,
          cloudName: '', // Empty cloud name
          signerBaseUrl: testSignerBaseUrl,
        );

        await expectLater(
          () => client.getUploadSignature(submissionId: testSubmissionId),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', contains('not configured'))),
        );
      });
    });

    group('uploadToCloudinary', () {
      test('should make multipart POST to Cloudinary and return result', () async {
        final testFileBytes = Uint8List.fromList([1, 2, 3, 4]); // Dummy image data
        const testFileName = 'test_image.jpg';
        const testContentType = 'image/jpeg';
        
        final signedParams = {
          'signature': 'test-signature',
          'timestamp': 1234567890,
          'api_key': 'test-api-key',
          'folder': 'test-folder',
          'public_id': 'test-public-id',
          'type': 'authenticated',
        };

        final expectedResponse = {
          'public_id': 'folder/test-public-id',
          'version': 1234567890,
        };

        mockHttpClient = MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(request.url.toString(), equals('https://api.cloudinary.com/v1_1/$testCloudName/image/upload'));
          
          // For multipart requests, we can't easily test the exact body,
          // but we can verify it's a multipart request
          expect(request.headers['content-type'], contains('multipart/form-data'));
          
          return http.Response(jsonEncode(expectedResponse), 200);
        });

        client = CloudinaryClient(
          httpClient: mockHttpClient,
          auth: mockAuth,
          cloudName: testCloudName,
          signerBaseUrl: testSignerBaseUrl,
        );

        final result = await client.uploadToCloudinary(
          fileBytes: testFileBytes,
          fileName: testFileName,
          contentType: testContentType,
          signedParams: signedParams,
        );

        expect(result.publicId, equals('folder/test-public-id'));
        expect(result.version, equals(1234567890));
      });

      test('should throw CloudinaryException with status and message on 401', () async {
        final testFileBytes = Uint8List.fromList([1, 2, 3, 4]);
        const testFileName = 'test_image.jpg';
        const testContentType = 'image/jpeg';
        
        final signedParams = {
          'signature': 'test-signature',
          'timestamp': 1234567890,
          'api_key': 'test-api-key',
        };

        final errorResponse = {
          'error': {
            'message': 'Invalid Signature',
          },
        };

        mockHttpClient = MockClient((request) async {
          return http.Response(jsonEncode(errorResponse), 401);
        });

        client = CloudinaryClient(
          httpClient: mockHttpClient,
          auth: mockAuth,
          cloudName: testCloudName,
          signerBaseUrl: testSignerBaseUrl,
        );

        await expectLater(
          () => client.uploadToCloudinary(
            fileBytes: testFileBytes,
            fileName: testFileName,
            contentType: testContentType,
            signedParams: signedParams,
          ),
          throwsA(isA<CloudinaryException>()
              .having((e) => e.message, 'message', contains('Invalid Signature'))
              .having((e) => e.message, 'message', contains('401'))
              .having((e) => e.code, 'code', '401')),
        );
      });

      test('should throw CloudinaryException on 200 with missing fields', () async {
        final testFileBytes = Uint8List.fromList([1, 2, 3, 4]);
        const testFileName = 'test_image.jpg';
        const testContentType = 'image/jpeg';
        
        final signedParams = {
          'signature': 'test-signature',
          'timestamp': 1234567890,
          'api_key': 'test-api-key',
        };

        final malformedResponse = {
          'upload_id': 'some-id',
          // Missing required 'public_id' and 'version' fields
        };

        mockHttpClient = MockClient((request) async {
          return http.Response(jsonEncode(malformedResponse), 200);
        });

        client = CloudinaryClient(
          httpClient: mockHttpClient,
          auth: mockAuth,
          cloudName: testCloudName,
          signerBaseUrl: testSignerBaseUrl,
        );

        await expectLater(
          () => client.uploadToCloudinary(
            fileBytes: testFileBytes,
            fileName: testFileName,
            contentType: testContentType,
            signedParams: signedParams,
          ),
          throwsA(isA<CloudinaryException>()
              .having((e) => e.message, 'message', contains('response format was unexpected'))
              .having((e) => e.code, 'code', '200')),
        );
      });
    });

    group('getViewUrl', () {
      test('should make correct POST request and return view URL', () async {
        const expectedUrl = 'https://res.cloudinary.com/test-cloud/image/authenticated/test-public-id?expires_at=123456789&signature=test-signature';

        mockHttpClient = MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(request.url.toString(), equals('$testSignerBaseUrl/sign-view'));
          expect(request.headers['Authorization'], equals('Bearer $testIdToken'));
          expect(request.headers['Content-Type'], equals('application/json'));
          
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['publicId'], equals(testPublicId));
          
          return http.Response(jsonEncode({'url': expectedUrl}), 200);
        });

        client = CloudinaryClient(
          httpClient: mockHttpClient,
          auth: mockAuth,
          cloudName: testCloudName,
          signerBaseUrl: testSignerBaseUrl,
        );

        final result = await client.getViewUrl(publicId: testPublicId);
        expect(result, equals(expectedUrl));
      });

      test('should throw CloudinaryException on non-200 response', () async {
        final errorResponse = {
          'error': 'Asset not found',
          'code': 'NOT_FOUND',
        };

        mockHttpClient = MockClient((request) async {
          return http.Response(jsonEncode(errorResponse), 404);
        });

        client = CloudinaryClient(
          httpClient: mockHttpClient,
          auth: mockAuth,
          cloudName: testCloudName,
          signerBaseUrl: testSignerBaseUrl,
        );

        await expectLater(
          () => client.getViewUrl(publicId: testPublicId),
          throwsA(isA<CloudinaryException>()
              .having((e) => e.message, 'message', 'Asset not found')
              .having((e) => e.code, 'code', 'NOT_FOUND')),
        );
      });
    });

    group('promote', () {
      test('should make correct POST request and return secure URL', () async {
        const expectedSecureUrl = 'https://res.cloudinary.com/test-cloud/image/upload/test-public-id.jpg';

        mockHttpClient = MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(request.url.toString(), equals('$testSignerBaseUrl/promote'));
          expect(request.headers['Authorization'], equals('Bearer $testIdToken'));
          expect(request.headers['Content-Type'], equals('application/json'));
          
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['submissionId'], equals(testSubmissionId));
          expect(body['placeId'], equals(testPlaceId));
          expect(body['publicId'], equals(testPublicId));
          
          return http.Response(jsonEncode({'secureUrl': expectedSecureUrl}), 200);
        });

        client = CloudinaryClient(
          httpClient: mockHttpClient,
          auth: mockAuth,
          cloudName: testCloudName,
          signerBaseUrl: testSignerBaseUrl,
        );

        final result = await client.promote(
          submissionId: testSubmissionId,
          placeId: testPlaceId,
          publicId: testPublicId,
        );
        expect(result, equals(expectedSecureUrl));
      });

      test('should throw CloudinaryException on non-200 response', () async {
        final errorResponse = {
          'error': 'Insufficient permissions',
          'code': 'FORBIDDEN',
        };

        mockHttpClient = MockClient((request) async {
          return http.Response(jsonEncode(errorResponse), 403);
        });

        client = CloudinaryClient(
          httpClient: mockHttpClient,
          auth: mockAuth,
          cloudName: testCloudName,
          signerBaseUrl: testSignerBaseUrl,
        );

        await expectLater(
          () => client.promote(
            submissionId: testSubmissionId,
            placeId: testPlaceId,
            publicId: testPublicId,
          ),
          throwsA(isA<CloudinaryException>()
              .having((e) => e.message, 'message', 'Insufficient permissions')
              .having((e) => e.code, 'code', 'FORBIDDEN')),
        );
      });
    });

    group('CloudinaryUploadResult', () {
      test('should create from JSON correctly', () {
        final json = {
          'public_id': 'folder/test-image',
          'version': 1234567890,
          'other_field': 'ignored',
        };

        final result = CloudinaryUploadResult.fromJson(json);
        expect(result.publicId, equals('folder/test-image'));
        expect(result.version, equals(1234567890));
      });
    });

    group('CloudinaryException', () {
      test('should format toString correctly with code', () {
        const exception = CloudinaryException('Test error', code: 'TEST_CODE');
        expect(exception.toString(), equals('CloudinaryException: Test error (code: TEST_CODE)'));
      });

      test('should format toString correctly without code', () {
        const exception = CloudinaryException('Test error');
        expect(exception.toString(), equals('CloudinaryException: Test error'));
      });
    });
  });
}