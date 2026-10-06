import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';
import '../models/accessibility_report.dart';

/// Service for submitting accessibility-information reports.
///
/// Reports are stored in the top-level `reports` collection so they are
/// easy for administrators to query across all places.
class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submits a new report for the given place.
  ///
  /// Validates that [reason] is not empty and that the user is signed in.
  Future<void> submitReport({
    required String placeId,
    required String placeName,
    required String reason,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Reason must not be empty');
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('User must be signed in to submit a report');
    }

    final docRef =
        _firestore.collection(FirestoreCollections.reports).doc();

    final report = AccessibilityReport(
      id: docRef.id,
      placeId: placeId,
      placeName: placeName,
      reporterUid: uid,
      reason: trimmed,
      status: ReportStatus.pending,
      createdAt: DateTime.now(),
    );

    await docRef.set(report.toFirestore());
  }

  /// Returns all reports submitted by the current user.
  Future<List<AccessibilityReport>> getMyReports() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snap = await _firestore
        .collection(FirestoreCollections.reports)
        .where('reporterUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((doc) => AccessibilityReport.fromFirestore(doc))
        .toList();
  }
}
