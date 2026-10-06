import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../core/database/firestore_collections.dart';
import '../models/place_photo.dart';

/// Service managing accessibility photos.
/// Uploads images to Firebase Storage under `places/{placeId}/photos/{filename}`
/// and saves metadata to `places/{placeId}/photos/{photoDocId}` in Firestore.
class PhotoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  String? get currentUserId => _auth.currentUser?.uid;

  /// Picks an image from [source], validates size/type, uploads it to Storage,
  /// and writes metadata to Firestore.
  /// Returns the created [PlacePhoto], or null if the user cancelled picking.
  Future<PlacePhoto?> pickAndUploadPhoto({
    required String placeId,
    String? caption,
    ImageSource source = ImageSource.gallery,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to upload a photo.');
    }

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile == null) {
      // User cancelled picker
      return null;
    }

    // Validate extension
    final fileName = pickedFile.name.toLowerCase();
    final parts = fileName.split('.');
    final ext = parts.length > 1 ? parts.last : 'jpg';

    if (!allowedExtensions.contains(ext)) {
      throw ArgumentError(
        'Invalid image format (.$ext). Supported formats are: JPG, PNG, and WEBP.',
      );
    }

    // Validate file size
    final bytes = await pickedFile.readAsBytes();
    if (bytes.length > maxFileSizeBytes) {
      final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      throw ArgumentError(
        'Image is too large (${sizeMb}MB). Maximum allowed size is 5MB.',
      );
    }

    final uid = user.uid;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'places/$placeId/photos/${uid}_$timestamp.$ext';
    final mimeType = ext == 'jpg' ? 'image/jpeg' : 'image/$ext';

    // 1. Upload to Firebase Storage
    final storageRef = _storage.ref().child(storagePath);
    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: {
        'placeId': placeId,
        'uploaderUid': uid,
      },
    );

    UploadTask uploadTask = storageRef.putData(bytes, metadata);
    final TaskSnapshot snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    // 2. Create Firestore metadata record
    final photoDoc = _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId)
        .collection(FirestoreCollections.photos)
        .doc();

    final photo = PlacePhoto(
      id: photoDoc.id,
      placeId: placeId,
      uploaderUid: uid,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      caption: caption,
      createdAt: DateTime.now(),
    );

    try {
      await photoDoc.set(photo.toFirestore());
    } catch (e) {
      // If Firestore metadata creation fails, attempt to delete uploaded file to avoid orphaned storage
      try {
        await storageRef.delete();
      } catch (_) {}
      rethrow;
    }

    return photo;
  }

  /// Real-time stream of photos for [placeId].
  Stream<List<PlacePhoto>> getPlacePhotosStream(String placeId) {
    return _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId)
        .collection(FirestoreCollections.photos)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => PlacePhoto.fromFirestore(doc)).toList());
  }

  /// Deletes a photo and its metadata.
  Future<void> deletePhoto(PlacePhoto photo) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('You must be signed in to delete a photo.');
    }

    // Delete Firestore record
    await _firestore
        .collection(FirestoreCollections.places)
        .doc(photo.placeId)
        .collection(FirestoreCollections.photos)
        .doc(photo.id)
        .delete();

    // Delete Storage item
    try {
      await _storage.ref().child(photo.storagePath).delete();
    } catch (_) {}
  }
}
