import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';
import '../models/submission.dart';
import '../utils/accessibility_compute.dart';
import 'cloudinary_client.dart';

/// Service for moderating submissions and managing place verification.
/// 
/// Implements idempotent, partial-failure-safe approval/rejection workflow:
/// - Photo approval: copies private pending Storage object to deterministic public path
/// - Accessibility approval: merges only changed features, recomputes score/flags
/// - Rejection: updates submission status with optional reason
/// - Place verification: explicit staff-level verification separate from feature verification
/// 
/// All operations are guarded by current user check and rely on Firestore rules
/// for authoritative access control.
class ModerationService {
  ModerationService({
    FirebaseFirestore? firestore,
    CloudinaryClient? cloudinaryClient,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudinaryClient = cloudinaryClient ?? CloudinaryClient(),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final CloudinaryClient _cloudinaryClient;
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  /// Approve a photo submission with idempotent, failure-safe workflow.
  /// 
  /// GUARD: Only processes pending submissions to prevent double-processing.
  /// 1. Promote Cloudinary asset from private pending to public deterministic path
  /// 2. Get public secure URL from Cloudinary
  /// 3. Firestore batch: update place photos (arrayUnion) + submission status
  /// 4. Pending private asset cleanup handled server-side via Cloudinary
  /// 
  /// Legacy submissions (empty cloudinaryPublicId) fail with clear error message.
  /// Deterministic promotion: same submissionId always yields same public asset.
  Future<void> approvePhoto(PhotoSubmission submission) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('User must be logged in to approve submissions');
    }

    if (submission.id == null) {
      throw ArgumentError('Submission ID is required for approval');
    }

    // GUARD: Only process pending submissions
    if (submission.status != SubmissionStatus.pending) {
      // Idempotent: already processed, no-op
      return;
    }

    // GUARD: Legacy submission handling - fail safely for old Firebase-era submissions
    if (submission.cloudinaryPublicId.isEmpty) {
      throw StateError('Legacy submission has no Cloudinary asset; cannot approve. Drain/migrate old pending submissions before cutover.');
    }

    try {
      // 1. Promote Cloudinary asset to public (deterministic and idempotent)
      final secureUrl = await _cloudinaryClient.promote(
        submissionId: submission.id!,
        placeId: submission.placeId,
        publicId: submission.cloudinaryPublicId,
      );

      // 2. Firestore batch transaction: update place + submission
      await _firestore.runTransaction((transaction) async {
        // Update place photos with arrayUnion (natural dedup)
        final placeRef = _firestore.collection(FirestoreCollections.places).doc(submission.placeId);
        transaction.update(placeRef, {
          'photos': FieldValue.arrayUnion([secureUrl]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update submission status
        final submissionRef = _firestore
            .collection(FirestoreCollections.contributions)
            .doc(submission.id!);
        transaction.update(submissionRef, {
          'status': SubmissionStatus.approved.name,
          'reviewedBy': user.uid,
          'reviewedAt': FieldValue.serverTimestamp(),
        });
      });

      // 3. Best-effort cleanup: pending private asset is handled server-side
      // Cloudinary cleanup via signer/server-side maintenance (no client-side cleanup needed)
      // The promote operation on server-side handles pending asset cleanup automatically
      
    } catch (e) {
      throw Exception('Failed to approve photo submission: $e');
    }
  }

  /// Approve an accessibility submission with feature merging and score recomputation.
  /// 
  /// GUARD: Only processes pending submissions to prevent double-processing.
  /// 1. Read current place accessibility (full 7-key map)
  /// 2. Merge ONLY the changed keys from submission payload
  /// 3. Set verified=true + lastUpdated for affected features
  /// 4. Recompute accessibilityScore + has* flags from merged data
  /// 5. Batch update: place accessibility + submission status
  /// 
  /// Does NOT set place-level placeVerified (that's a separate explicit action).
  Future<void> approveAccessibility(AccessibilitySubmission submission) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('User must be logged in to approve submissions');
    }

    if (submission.id == null) {
      throw ArgumentError('Submission ID is required for approval');
    }

    // GUARD: Only process pending submissions
    if (submission.status != SubmissionStatus.pending) {
      // Idempotent: already processed, no-op
      return;
    }

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Read current place accessibility
        final placeRef = _firestore.collection(FirestoreCollections.places).doc(submission.placeId);
        final placeDoc = await transaction.get(placeRef);
        
        if (!placeDoc.exists) {
          throw StateError('Place ${submission.placeId} not found');
        }

        final placeData = placeDoc.data()!;
        final currentAccessibility = Map<String, dynamic>.from(
          placeData['accessibility'] as Map<String, dynamic>? ?? <String, dynamic>{},
        );

        // 2. Merge ONLY the submission payload changed keys
        final mergedAccessibility = Map<String, dynamic>.from(currentAccessibility);
        final now = FieldValue.serverTimestamp();

        for (final entry in submission.payload.entries) {
          final featureKey = entry.key;
          final changes = entry.value;

          // Initialize feature if it doesn't exist
          if (mergedAccessibility[featureKey] == null) {
            mergedAccessibility[featureKey] = <String, dynamic>{};
          }

          final feature = mergedAccessibility[featureKey] as Map<String, dynamic>;

          // Apply changes: available + notes from payload, set verified=true, lastUpdated=now
          feature['available'] = changes['available'] ?? feature['available'] ?? false;
          feature['notes'] = changes['notes'] ?? feature['notes'] ?? '';
          feature['verified'] = true;
          feature['lastUpdated'] = now;
        }

        // 3. Recompute accessibilityScore + has* flags from merged data
        final accessibilityScore = computeAccessibilityScore(mergedAccessibility);
        final flags = computeAccessibilityFlags(mergedAccessibility);

        // 4. Batch update: place accessibility + submission status
        transaction.update(placeRef, {
          'accessibility': mergedAccessibility,
          'accessibilityScore': accessibilityScore,
          ...flags, // hasWheelchairAccess, hasAccessibleToilet, etc.
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update submission status
        final submissionRef = _firestore
            .collection(FirestoreCollections.accessibilityFeatures)
            .doc(submission.id!);
        transaction.update(submissionRef, {
          'status': SubmissionStatus.approved.name,
          'reviewedBy': user.uid,
          'reviewedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to approve accessibility submission: $e');
    }
  }

  /// Reject a submission with optional reason.
  /// 
  /// Updates submission status to rejected with optional rejection reason.
  /// Does NOT modify the associated place - only updates submission record.
  Future<void> reject(dynamic submission, {String? reason}) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('User must be logged in to reject submissions');
    }

    String submissionId;
    String collection;

    // Determine submission type and collection
    if (submission is PhotoSubmission) {
      if (submission.id == null) {
        throw ArgumentError('Photo submission ID is required for rejection');
      }
      submissionId = submission.id!;
      collection = FirestoreCollections.contributions;
    } else if (submission is AccessibilitySubmission) {
      if (submission.id == null) {
        throw ArgumentError('Accessibility submission ID is required for rejection');
      }
      submissionId = submission.id!;
      collection = FirestoreCollections.accessibilityFeatures;
    } else {
      throw ArgumentError('Unknown submission type: ${submission.runtimeType}');
    }

    try {
      await _firestore.collection(collection).doc(submissionId).update({
        'status': SubmissionStatus.rejected.name,
        'rejectionReason': reason, // Can be null
        'reviewedBy': user.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reject submission: $e');
    }
  }

  /// Mark a place as verified or unverified by staff.
  /// 
  /// This is an explicit staff action separate from feature-level verification.
  /// Sets placeVerified field which is used for place verification badges.
  /// 
  /// When verified=true: sets verifiedBy=currentUser.uid, verifiedAt=now
  /// When verified=false: clears verifiedBy and verifiedAt fields
  Future<void> markPlaceVerified(String placeId, bool verified) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('User must be logged in to verify places');
    }

    try {
      final updateData = <String, dynamic>{
        'placeVerified': verified,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (verified) {
        updateData['verifiedBy'] = user.uid;
        updateData['verifiedAt'] = FieldValue.serverTimestamp();
      } else {
        // Clear verification fields when unmarking
        updateData['verifiedBy'] = null;
        updateData['verifiedAt'] = null;
      }

      await _firestore
          .collection(FirestoreCollections.places)
          .doc(placeId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update place verification: $e');
    }
  }
}

/// NOTE: Orphan cleanup for leftover pending Cloudinary assets
/// 
/// When approvePhoto() successfully updates Firestore but the Cloudinary promote
/// operation is interrupted, the private pending asset may remain in Cloudinary.
/// 
/// Cleanup is handled server-side via the signer service and Cloudinary's maintenance
/// operations. The client has no Cloudinary secrets and cannot directly delete assets.
/// 
/// Server-side cleanup can:
/// 1. Query Firestore for submission statuses
/// 2. List pending assets in Cloudinary matching pattern
/// 3. Delete assets where corresponding submission.status != 'pending'
/// 
/// This cleanup is not implemented in the client but should be part of regular
/// server-side maintenance operations.