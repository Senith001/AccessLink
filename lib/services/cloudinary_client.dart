import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/cloudinary_config.dart';

/// Result of a Cloudinary upload operation
class CloudinaryUploadResult {
  final String publicId;
  final int version;

  const CloudinaryUploadResult({
    required this.publicId,
    required this.version,
  });

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResult(
      publicId: json['public_id'] as String,
      version: json['version'] as int,
    );
  }
}

/// Exception thrown when Cloudinary operations fail
class CloudinaryException implements Exception {
  final String message;
  final String? code;

  const CloudinaryException(this.message, {this.code});

  @override
  String toString() => 'CloudinaryException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Client for Cloudinary operations that talks to a backend signer service
/// and uploads to Cloudinary's authenticated endpoint.
/// 
/// This client holds NO secrets - only the cloud name and signer base URL.
/// All authentication is handled via Firebase ID tokens and the backend signer.
class CloudinaryClient {
  final http.Client _httpClient;
  final FirebaseAuth _auth;
  final String _cloudName;
  final String _signerBaseUrl;

  CloudinaryClient({
    http.Client? httpClient,
    FirebaseAuth? auth,
    String? cloudName,
    String? signerBaseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance,
        _cloudName = cloudName ?? CloudinaryConfig.cloudName,
        _signerBaseUrl = signerBaseUrl ?? CloudinaryConfig.signerBaseUrl;

  /// Gets upload signature and parameters from the backend signer service
  /// 
  /// Throws [StateError] if user is not authenticated or config is invalid
  /// Throws [CloudinaryException] if the signer service returns an error
  Future<Map<String, dynamic>> getUploadSignature({
    required String submissionId,
  }) async {
    _ensureConfigured();
    
    final idToken = await _getIdToken();
    
    final response = await _httpClient.post(
      Uri.parse('$_signerBaseUrl/sign-upload'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'submissionId': submissionId}),
    );

    if (response.statusCode != 200) {
      if (kDebugMode) {
        log('[CloudinaryClient] sign-upload status=${response.statusCode}');
      }
      final errorData = _parseErrorResponse(response);
      throw CloudinaryException(
        errorData['error'] ?? 'Failed to get upload signature',
        code: errorData['code'],
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Uploads file bytes to Cloudinary using signed parameters
  /// 
  /// Throws [CloudinaryException] if upload fails
  Future<CloudinaryUploadResult> uploadToCloudinary({
    required Uint8List fileBytes,
    required String fileName,
    required String contentType,
    required Map<String, dynamic> signedParams,
  }) async {
    _ensureConfigured();

    if (kDebugMode) {
      log('[CloudinaryClient] Uploading to Cloudinary: status pending, signed params keys: ${signedParams.keys.toList()}');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload'),
    );

    // Add all signed parameters
    signedParams.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    // Add the file using bytes
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType.parse(contentType),
    ));

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      if (kDebugMode) {
        log('[CloudinaryClient] Upload failed status=${response.statusCode}, body: ${response.body}');
      }
      
      String errorMessage;
      try {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final cloudinaryError = errorData['error']?['message'] ?? 'Upload failed';
        errorMessage = 'Cloudinary upload failed (${response.statusCode}): $cloudinaryError';
      } catch (_) {
        // If JSON parsing fails, include a trimmed snippet of raw body
        final snippet = response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body;
        errorMessage = 'Cloudinary upload failed (${response.statusCode}): $snippet';
      }
      
      throw CloudinaryException(
        errorMessage,
        code: response.statusCode.toString(),
      );
    }

    try {
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final result = CloudinaryUploadResult.fromJson(responseData);
      
      if (kDebugMode) {
        log('[CloudinaryClient] Upload OK status=200 publicId=${result.publicId}');
      }
      
      return result;
    } catch (e) {
      // CloudinaryUploadResult.fromJson threw - missing required fields
      if (kDebugMode) {
        log('[CloudinaryClient] Upload parsing failed: $e, response body: ${response.body}');
      }
      throw CloudinaryException(
        'Cloudinary upload succeeded but response format was unexpected: ${response.body}',
        code: '200',
      );
    }
  }

  /// Gets a short-lived signed URL for viewing an authenticated asset
  /// 
  /// STAFF ONLY: Requires appropriate permissions
  /// Throws [StateError] if user is not authenticated or config is invalid
  /// Throws [CloudinaryException] if the signer service returns an error
  Future<String> getViewUrl({required String publicId}) async {
    _ensureConfigured();
    
    final idToken = await _getIdToken();
    
    final response = await _httpClient.post(
      Uri.parse('$_signerBaseUrl/sign-view'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'publicId': publicId}),
    );

    if (response.statusCode != 200) {
      final errorData = _parseErrorResponse(response);
      throw CloudinaryException(
        errorData['error'] ?? 'Failed to get view URL',
        code: errorData['code'],
      );
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    return responseData['url'] as String;
  }

  /// Promotes a submission to public and returns the public secure URL
  /// 
  /// STAFF ONLY: Requires appropriate permissions
  /// Throws [StateError] if user is not authenticated or config is invalid
  /// Throws [CloudinaryException] if the signer service returns an error
  Future<String> promote({
    required String submissionId,
    required String placeId,
    required String publicId,
  }) async {
    _ensureConfigured();
    
    final idToken = await _getIdToken();
    
    final response = await _httpClient.post(
      Uri.parse('$_signerBaseUrl/promote'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'submissionId': submissionId,
        'placeId': placeId,
        'publicId': publicId,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = _parseErrorResponse(response);
      throw CloudinaryException(
        errorData['error'] ?? 'Failed to promote submission',
        code: errorData['code'],
      );
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    return responseData['secureUrl'] as String;
  }

  /// Ensures the client is properly configured
  void _ensureConfigured() {
    if (_cloudName.isEmpty || _signerBaseUrl.isEmpty) {
      throw StateError(
        'Cloudinary client not configured. Ensure CLOUDINARY_CLOUD_NAME and SIGNER_BASE_URL are set via --dart-define',
      );
    }
  }

  /// Gets the current user's Firebase ID token
  Future<String> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User must be authenticated to use Cloudinary');
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw StateError('Failed to get ID token from Firebase Auth');
    }
    return token;
  }

  /// Parses error response from the signer service
  Map<String, dynamic> _parseErrorResponse(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': 'Unknown error (${response.statusCode})'};
    }
  }
}