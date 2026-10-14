import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';
import '../models/submission.dart';

class SubmissionRepository {
  SubmissionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  /// Create an accessibility feature submission
  Future<String> createAccessibilitySubmission({
    required String placeId,
    required String placeName,
    required AccessibilityKind kind,
    required Map<String, Map<String, dynamic>> payload,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('Please log in to submit accessibility updates.');
    }

    final submission = AccessibilitySubmission(
      type: SubmissionType.accessibility,
      placeId: placeId,
      placeName: placeName,
      submittedBy: user.uid,
      submitterName: user.displayName ?? user.email ?? 'Anonymous',
      kind: kind,
      payload: payload,
      status: SubmissionStatus.pending,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection(FirestoreCollections.accessibilityFeatures)
        .add(submission.toMap());

    return docRef.id;
  }

  /// Watch pending photo submissions for admin panel (Phase 6)
  Stream<List<PhotoSubmission>> watchPendingPhotoSubmissions() {
    return _firestore
        .collection(FirestoreCollections.contributions)
        .where('status', isEqualTo: SubmissionStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PhotoSubmission.fromData(doc.data(), id: doc.id))
          .whereType<PhotoSubmission>()
          .toList();
    });
  }

  /// Watch pending accessibility submissions for admin panel (Phase 6)
  Stream<List<AccessibilitySubmission>> watchPendingAccessibilitySubmissions() {
    return _firestore
        .collection(FirestoreCollections.accessibilityFeatures)
        .where('status', isEqualTo: SubmissionStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AccessibilitySubmission.fromData(doc.data(), id: doc.id))
          .whereType<AccessibilitySubmission>()
          .toList();
    });
  }

  /// Get user's photo submissions
  Stream<List<PhotoSubmission>> watchUserPhotoSubmissions() {
    final user = currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection(FirestoreCollections.contributions)
        .where('submittedBy', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PhotoSubmission.fromData(doc.data(), id: doc.id))
          .whereType<PhotoSubmission>()
          .toList();
    });
  }

  /// Get user's accessibility submissions
  Stream<List<AccessibilitySubmission>> watchUserAccessibilitySubmissions() {
    final user = currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection(FirestoreCollections.accessibilityFeatures)
        .where('submittedBy', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AccessibilitySubmission.fromData(doc.data(), id: doc.id))
          .whereType<AccessibilitySubmission>()
          .toList();
    });
  }
}