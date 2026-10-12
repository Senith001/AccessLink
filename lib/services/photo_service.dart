import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../core/database/firestore_collections.dart';
import '../models/place_photo.dart';

class PhotoValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? mimeType;
  final String? extension;

  const PhotoValidationResult({
    required this.isValid,
    this.errorMessage,
    this.mimeType,
    this.extension,
  });
}

class PhotoService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final ImagePicker _picker;

  PhotoService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    ImagePicker? picker,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _picker = picker ?? ImagePicker();

  User? get currentUser => _auth.currentUser;

  /// Validate image content format using magic numbers and byte size
  static PhotoValidationResult validateImage(
    Uint8List bytes, {
    int maxSizeBytes = 10 * 1024 * 1024,
  }) {
    if (bytes.isEmpty) {
      return const PhotoValidationResult(
        isValid: false,
        errorMessage: 'Selected file is empty or corrupted.',
      );
    }

    if (bytes.length > maxSizeBytes) {
      final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      return PhotoValidationResult(
        isValid: false,
        errorMessage:
            'Image size ($sizeMb MB) exceeds the maximum allowed limit of 10 MB.',
      );
    }

    // Check Magic Bytes
    // JPEG: FF D8 FF
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return const PhotoValidationResult(
        isValid: true,
        mimeType: 'image/jpeg',
        extension: 'jpg',
      );
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return const PhotoValidationResult(
        isValid: true,
        mimeType: 'image/png',
        extension: 'png',
      );
    }

    // WebP: RIFF ... WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return const PhotoValidationResult(
        isValid: true,
        mimeType: 'image/webp',
        extension: 'webp',
      );
    }

    return const PhotoValidationResult(
      isValid: false,
      errorMessage:
          'Unsupported image format. Please select a valid JPEG or PNG file.',
    );
  }

  /// Pick image from gallery or camera
  Future<XFile?> pickImage({required ImageSource source}) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
    } catch (e) {
      throw StateError('Could not access image picker: $e');
    }
  }

  /// Upload photo with persistent storage, metadata linking, and rollback on failure
  Future<PlacePhoto> uploadPlacePhoto({
    required String placeId,
    required Uint8List bytes,
    required String fileName,
    String caption = '',
    void Function(double progress)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to upload accessibility photos.');
    }

    final validation = validateImage(bytes);
    if (!validation.isValid) {
      throw ArgumentError(validation.errorMessage);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final photoId = 'photo_${placeId}_${user.uid}_$timestamp';
    final ext = validation.extension ?? 'jpg';
    final storagePath = 'places/$placeId/photos/$photoId.$ext';

    // 1. Upload to Firebase Storage
    Reference storageRef = _storage.ref().child(storagePath);
    final metadata = SettableMetadata(
      contentType: validation.mimeType ?? 'image/jpeg',
      customMetadata: {
        'placeId': placeId,
        'uploaderId': user.uid,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    String downloadUrl;
    try {
      final uploadTask = storageRef.putData(bytes, metadata);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress);
          }
        });
      }

      final snapshot = await uploadTask;
      downloadUrl = await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw StateError('Storage upload failed: $e');
    }

    // Resolve uploader name
    String uploaderName =
        user.displayName ?? user.email?.split('@').first ?? 'Contributor';
    try {
      final userDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()?['name'] != null) {
        uploaderName = userDoc.data()!['name'];
      }
    } catch (_) {}

    final placePhoto = PlacePhoto(
      id: photoId,
      placeId: placeId,
      uploaderId: user.uid,
      uploaderName: uploaderName,
      url: downloadUrl,
      storagePath: storagePath,
      caption: caption.trim(),
      createdAt: DateTime.now(),
    );

    // 2. Save metadata to Firestore and link to Place
    try {
      await _firestore
          .collection(FirestoreCollections.photos)
          .doc(photoId)
          .set(placePhoto.toMap());

      await _firestore
          .collection(FirestoreCollections.places)
          .doc(placeId)
          .update({
            'photos': FieldValue.arrayUnion([downloadUrl]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      // Rollback to avoid orphaned files in storage
      try {
        await storageRef.delete();
      } catch (_) {}
      throw StateError('Failed to record photo metadata: $e');
    }

    return placePhoto;
  }

  /// Get all photo records for a place
  Future<List<PlacePhoto>> getPhotosForPlace(String placeId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.photos)
          .where('placeId', isEqualTo: placeId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => PlacePhoto.fromFirestore(doc)).toList();
    } catch (_) {
      try {
        final snapshot = await _firestore
            .collection(FirestoreCollections.photos)
            .where('placeId', isEqualTo: placeId)
            .get();

        return snapshot.docs
            .map((doc) => PlacePhoto.fromFirestore(doc))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }
}
