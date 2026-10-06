import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';
import '../models/accessibility_report.dart';

/// Service for admin-level operations: reviewing reports, approving /
/// rejecting them, and optionally updating the linked place with corrected
/// accessibility information.
///
/// Admin status is verified via a Firebase Auth custom claim:
///   `{ "admin": true }`
///
/// This claim must be set server-side (Firebase Admin SDK or a Cloud
/// Function). See the setup documentation for details.
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns `true` if the currently signed-in user has the `admin`
  /// custom claim set to `true`.
  ///
  /// Forces a token refresh to pick up recently-granted claims.
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Force refresh to get latest custom claims.
    final tokenResult = await user.getIdTokenResult(true);
    return tokenResult.claims?['admin'] == true;
  }

  /// Fetches all reports, ordered newest-first.
  Future<List<AccessibilityReport>> getAllReports() async {
    final snap = await _firestore
        .collection(FirestoreCollections.reports)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => AccessibilityReport.fromFirestore(doc))
        .toList();
  }

  /// Approves a report.
  ///
  /// Optionally accepts [correctedInfo] to write updated accessibility
  /// data to the linked place document. Uses a transaction to prevent
  /// processing the same report twice (checks that current status is
  /// still `pending`).
  Future<void> approveReport(
    String reportId, {
    String? correctedInfo,
  }) async {
    await _reviewReport(
      reportId: reportId,
      newStatus: ReportStatus.approved,
      correctedInfo: correctedInfo,
    );
  }

  /// Rejects a report.
  Future<void> rejectReport(String reportId) async {
    await _reviewReport(
      reportId: reportId,
      newStatus: ReportStatus.rejected,
    );
  }

  Future<void> _reviewReport({
    required String reportId,
    required ReportStatus newStatus,
    String? correctedInfo,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('User must be signed in');
    }

    final reportRef =
        _firestore.collection(FirestoreCollections.reports).doc(reportId);

    await _firestore.runTransaction((transaction) async {
      final reportSnap = await transaction.get(reportRef);
      if (!reportSnap.exists) {
        throw StateError('Report not found');
      }

      final currentStatus = reportSnap.data()?['status'] as String?;
      if (currentStatus != 'pending') {
        throw StateError(
          'Report has already been processed (status: $currentStatus)',
        );
      }

      // Update report status.
      final Map<String, dynamic> updateData = {
        'status': newStatus.name,
        'reviewerUid': uid,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (newStatus == ReportStatus.approved) {
        final placeId = reportSnap.data()?['placeId'] as String?;
        if (placeId != null && placeId.isNotEmpty) {
          final placeRef = _firestore
              .collection(FirestoreCollections.places)
              .doc(placeId);
          final Map<String, dynamic> placeUpdate = {
            'isVerified': true,
            'verifiedAt': Timestamp.fromDate(DateTime.now()),
          };
          if (correctedInfo != null && correctedInfo.trim().isNotEmpty) {
            placeUpdate['correctedAccessibilityInfo'] = correctedInfo.trim();
          }
          transaction.set(
            placeRef,
            placeUpdate,
            SetOptions(merge: true),
          );
        }
      }

      if (correctedInfo != null && correctedInfo.trim().isNotEmpty) {
        updateData['correctedInfo'] = correctedInfo.trim();
      }

      transaction.update(reportRef, updateData);
    });
  }
}
