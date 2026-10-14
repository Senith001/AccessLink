import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../core/database/firestore_collections.dart';
import '../models/submission.dart';
import 'cloudinary_client.dart';

class PhotoUploadService {
  PhotoUploadService({
    CloudinaryClient? cloudinaryClient,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    ImagePicker? imagePicker,
  })  : _cloudinaryClient = cloudinaryClient ?? CloudinaryClient(),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _imagePicker = imagePicker ?? ImagePicker();

  final CloudinaryClient _cloudinaryClient;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final ImagePicker _imagePicker;

  User? get currentUser => _auth.currentUser;

  /// Pick an image from gallery and submit it as a photo contribution
  /// Returns the submission ID if successful, null if cancelled, throws StateError on auth issues
  Future<String?> pickAndSubmitPhoto({
    required String placeId,
    required String placeName,
    Function(double)? onProgress,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('Please log in to submit a photo.');
    }

    // Pick image from gallery
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // Compress to reasonable quality
    );

    if (pickedFile == null) {
      // User cancelled selection
      return null;
    }

    // Validate file size (<=5MB)
    final file = File(pickedFile.path);
    final fileSize = await file.length();
    const maxSize = 5 * 1024 * 1024; // 5MB in bytes
    
    if (fileSize > maxSize) {
      throw ArgumentError('Image too large. Please select an image smaller than 5MB.');
    }

    // Validate content type is image
    final mimeType = lookupMimeType(pickedFile.path);
    if (mimeType == null || !mimeType.startsWith('image/')) {
      throw ArgumentError('Invalid file type. Please select an image file.');
    }

    // Generate submission ID
    final submissionId = _firestore.collection(FirestoreCollections.contributions).doc().id;

    try {
      // Get upload signature from Cloudinary signer service
      final signedParams = await _cloudinaryClient.getUploadSignature(
        submissionId: submissionId,
      );

      // Read file bytes and get metadata
      final file = File(pickedFile.path);
      final fileBytes = await file.readAsBytes();
      final fileName = pickedFile.name;

      // Upload to Cloudinary using bytes
      final uploadResult = await _cloudinaryClient.uploadToCloudinary(
        fileBytes: fileBytes,
        fileName: fileName,
        contentType: mimeType,
        signedParams: signedParams,
      );

      // Create submission document in Firestore
      final submission = PhotoSubmission(
        type: SubmissionType.photo,
        placeId: placeId,
        placeName: placeName,
        submittedBy: user.uid,
        submitterName: user.displayName ?? user.email ?? 'Anonymous',
        cloudinaryPublicId: uploadResult.publicId,
        cloudinaryVersion: uploadResult.version.toString(),
        status: SubmissionStatus.pending,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(FirestoreCollections.contributions)
          .doc(submissionId)
          .set(submission.toMap());

      return submissionId;
    } catch (e) {
      // If Firestore write fails after successful Cloudinary upload, we cannot
      // delete the Cloudinary asset from client-side (requires api_secret).
      // An orphaned private pending asset may remain. This is handled by
      // backend signer maintenance cleanup for orphaned submissions.
      
      if (kDebugMode) {
        log('[PhotoUploadService] photo submission failed: ${e.runtimeType}: $e');
      }
      rethrow;
    }
  }
}