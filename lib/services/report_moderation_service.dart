import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';
import '../models/accessibility_report.dart';
import '../models/place_detail.dart';

class ReportModerationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ReportModerationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Check if the currently signed-in user has staff (admin/moderator) role
  Future<bool> isUserStaff() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return false;
      final role = userDoc.data()?['role'] as String?;
      return role == 'admin' || role == 'moderator';
    } catch (_) {
      return false;
    }
  }

  /// Submit a new accessibility issue report
  Future<AccessibilityReport> submitReport({
    required String placeId,
    required String placeName,
    required String category,
    required String targetField,
    required String description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to submit a report.');
    }

    final trimmedReason = description.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError('Please provide a reason for this report.');
    }

    if (trimmedReason.length > 2000) {
      throw ArgumentError('Report reason cannot exceed 2,000 characters.');
    }

    // Check place exists
    final placeDoc = await _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId)
        .get();
    if (!placeDoc.exists) {
      throw StateError('The reported place no longer exists.');
    }

    // Prevent duplicate pending reports from the same user for the same place & field
    final duplicateQuery = await _firestore
        .collection(FirestoreCollections.reports)
        .where('placeId', isEqualTo: placeId)
        .where('reportedBy', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .where('targetField', isEqualTo: targetField)
        .limit(1)
        .get();

    if (duplicateQuery.docs.isNotEmpty) {
      throw StateError(
        'You already have a pending report for this item. Our team is reviewing it.',
      );
    }

    // Resolve reporter name
    String reporterName =
        user.displayName ??
        user.email?.split('@').first ??
        'Community Contributor';
    try {
      final userDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()?['name'] != null) {
        reporterName = userDoc.data()!['name'];
      }
    } catch (_) {}

    final reportRef = _firestore.collection(FirestoreCollections.reports).doc();
    final report = AccessibilityReport(
      id: reportRef.id,
      placeId: placeId,
      placeName: placeName.isNotEmpty
          ? placeName
          : (placeDoc.data()?['name'] as String? ?? 'Place'),
      reportedBy: user.uid,
      reporterName: reporterName,
      category: category,
      targetField: targetField,
      description: trimmedReason,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await reportRef.set({
      'placeId': report.placeId,
      'placeName': report.placeName,
      'reportedBy': report.reportedBy,
      'reporterName': report.reporterName,
      'category': report.category,
      'targetField': report.targetField,
      'description': report.description,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return report;
  }

  /// Get reports for administrator (or filtered by status)
  Future<List<AccessibilityReport>> getReports({String? statusFilter}) async {
    Query<Map<String, dynamic>> query = _firestore.collection(
      FirestoreCollections.reports,
    );

    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    try {
      final snapshot = await query.orderBy('createdAt', descending: true).get();
      return snapshot.docs.map(AccessibilityReport.fromFirestore).toList();
    } catch (_) {
      // Fallback query if composite index is pending
      final snapshot = await query.get();
      final list = snapshot.docs
          .map(AccessibilityReport.fromFirestore)
          .toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return list;
    }
  }

  /// Approve a report (records moderation note)
  Future<void> approveReport({
    required String reportId,
    required String adminNotes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in as administrator.');
    }

    final reportRef = _firestore
        .collection(FirestoreCollections.reports)
        .doc(reportId);
    final reportSnapshot = await reportRef.get();
    if (!reportSnapshot.exists) {
      throw StateError('Report could not be found.');
    }

    final currentStatus = reportSnapshot.data()?['status'] as String?;
    if (currentStatus != 'pending') {
      throw StateError(
        'This report has already been reviewed (current status: $currentStatus).',
      );
    }

    String adminName = user.displayName ?? user.email ?? 'Staff Reviewer';
    try {
      final userDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()?['name'] != null) {
        adminName = userDoc.data()!['name'];
      }
    } catch (_) {}

    await reportRef.update({
      'status': 'approved',
      'adminNotes': adminNotes.trim(),
      'reviewedBy': user.uid,
      'reviewedByName': adminName,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject a report (records moderation note)
  Future<void> rejectReport({
    required String reportId,
    required String adminNotes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in as administrator.');
    }

    final reportRef = _firestore
        .collection(FirestoreCollections.reports)
        .doc(reportId);
    final reportSnapshot = await reportRef.get();
    if (!reportSnapshot.exists) {
      throw StateError('Report could not be found.');
    }

    final currentStatus = reportSnapshot.data()?['status'] as String?;
    if (currentStatus != 'pending') {
      throw StateError(
        'This report has already been reviewed (current status: $currentStatus).',
      );
    }

    String adminName = user.displayName ?? user.email ?? 'Staff Reviewer';
    try {
      final userDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()?['name'] != null) {
        adminName = userDoc.data()!['name'];
      }
    } catch (_) {}

    await reportRef.update({
      'status': 'rejected',
      'adminNotes': adminNotes.trim(),
      'reviewedBy': user.uid,
      'reviewedByName': adminName,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Resolve report with updated place information
  Future<void> resolveReportWithPlaceUpdate({
    required String reportId,
    required String placeId,
    required Map<String, dynamic> updatedPlaceFields,
    required String adminNotes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in as administrator.');
    }

    final reportRef = _firestore
        .collection(FirestoreCollections.reports)
        .doc(reportId);
    final reportSnapshot = await reportRef.get();
    if (!reportSnapshot.exists) {
      throw StateError('Report could not be found.');
    }

    final currentStatus = reportSnapshot.data()?['status'] as String?;
    if (currentStatus == 'resolved') {
      throw StateError('This report is already resolved.');
    }

    String adminName = user.displayName ?? user.email ?? 'Staff Reviewer';
    try {
      final userDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()?['name'] != null) {
        adminName = userDoc.data()!['name'];
      }
    } catch (_) {}

    // Update place in firestore
    final placeRef = _firestore
        .collection(FirestoreCollections.places)
        .doc(placeId);
    final placeDoc = await placeRef.get();
    if (!placeDoc.exists) {
      throw StateError('Target place was not found.');
    }

    final fieldsToUpdate = Map<String, dynamic>.from(updatedPlaceFields);
    fieldsToUpdate['updatedAt'] = FieldValue.serverTimestamp();

    await placeRef.update(fieldsToUpdate);

    // Mark report resolved
    await reportRef.update({
      'status': 'resolved',
      'adminNotes': adminNotes.trim(),
      'reviewedBy': user.uid,
      'reviewedByName': adminName,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
