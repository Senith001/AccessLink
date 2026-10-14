import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';
import '../models/accessibility_report.dart';

class ReportModerationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ReportModerationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<User> _requireStaff() async {
    final user = currentUser;
    if (user == null || !await isUserStaff()) {
      throw StateError('Administrator or moderator access is required.');
    }
    return user;
  }

  static const reportCategories = {
    'incorrect_accessibility', 'outdated_info', 'inappropriate_content', 'other',
  };
  static const reportTargets = {
    'Wheelchair Accessible', 'Accessible Toilet', 'Elevator',
    'Accessible Parking', 'Tactile Paving', 'Audio Support', 'Hearing Support',
    'Opening Hours', 'Contact Information', 'General Information',
  };

  Stream<List<AccessibilityReport>> watchMyReports() {
    final user = currentUser;
    if (user == null) throw StateError('Please sign in.');
    return _firestore.collection(FirestoreCollections.reports)
      .where('reportedBy', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true).snapshots()
      .map((s) => s.docs.map(AccessibilityReport.fromFirestore).toList());
  }


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

    if (!reportCategories.contains(category) || !reportTargets.contains(targetField)) {
      throw ArgumentError('Choose a valid report category and field.');
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

    final lockId = Uri.encodeComponent('${placeId}_$targetField');
    final lockRef = _firestore.collection(FirestoreCollections.users).doc(user.uid)
        .collection('reportLocks').doc(lockId);
    await _firestore.runTransaction((tx) async {
      final place = await tx.get(_firestore.collection(FirestoreCollections.places).doc(placeId));
      final lock = await tx.get(lockRef);
      if (!place.exists) throw StateError('This place no longer exists.');
      final oldId = lock.data()?['reportId'] as String?;
      if (oldId != null) {
        final old = await tx.get(_firestore.collection(FirestoreCollections.reports).doc(oldId));
        if (old.exists && ['pending', 'approved'].contains(old.data()?['status'])) {
          throw StateError('You already have an open report for this item.');
        }
      }
      tx.set(reportRef, {
        ...report.toMap(),
        'lockId': lockId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(lockRef, {'reportId': reportRef.id, 'placeId': placeId, 'targetField': targetField});
    });

    return report;
  }

  /// Get reports for administrator (or filtered by status)
  Future<List<AccessibilityReport>> getReports({String? statusFilter}) async {
    await _requireStaff();
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
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
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

  Future<void> approveReport({required String reportId, required String adminNotes}) =>
      _moderate(reportId, 'approved', adminNotes);

  Future<void> rejectReport({required String reportId, required String adminNotes}) =>
      _moderate(reportId, 'rejected', adminNotes);

  Future<void> _moderate(String reportId, String status, String note) async {
    final user = await _requireStaff();
    if (note.trim().isEmpty || note.trim().length > 2000) {
      throw ArgumentError('Enter a moderation note of 1–2,000 characters.');
    }
    final ref = _firestore.collection(FirestoreCollections.reports).doc(reportId);
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists || doc.data()?['status'] != 'pending') {
        throw StateError('This report is missing or has already been reviewed. Refresh the list.');
      }
      tx.update(ref, _moderationFields(user, status, note));
    });
  }

  Map<String, dynamic> _moderationFields(User user, String status, String note) => {
    'status': status,
    'adminNotes': note.trim(),
    'reviewedBy': user.uid,
    'reviewedByName': user.displayName ?? user.email ?? 'Staff Reviewer',
    'reviewedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Future<void> resolveReportWithPlaceUpdate({
    required String reportId,
    required String placeId,
    required Map<String, dynamic> updatedPlaceFields,
    required String adminNotes,
  }) async {
    final user = await _requireStaff();
    if (adminNotes.trim().isEmpty || adminNotes.trim().length > 2000) {
      throw ArgumentError('Enter a resolution note of 1–2,000 characters.');
    }
    validatePlaceUpdate(updatedPlaceFields);
    final reportRef = _firestore.collection(FirestoreCollections.reports).doc(reportId);
    final placeRef = _firestore.collection(FirestoreCollections.places).doc(placeId);
    await _firestore.runTransaction((tx) async {
      final report = await tx.get(reportRef);
      final place = await tx.get(placeRef);
      if (!report.exists || !place.exists) throw StateError('Report or place no longer exists.');
      if (report.data()?['placeId'] != placeId) throw StateError('This report belongs to a different place.');
      if (!['pending', 'approved'].contains(report.data()?['status'])) {
        throw StateError('Only pending or approved reports can be resolved.');
      }
      final previous = <String, dynamic>{};
      for (final key in updatedPlaceFields.keys) { previous[key] = place.data()?[key]; }
      _writePlaceAndVerification(tx, placeRef, place.data()!, updatedPlaceFields, user);
      tx.update(reportRef, {
        ..._moderationFields(user, 'resolved', adminNotes),
        'previousPlaceValues': previous,
        'updatedPlaceValues': updatedPlaceFields,
      });
    });
  }

  Future<void> updatePlaceInformation({required String placeId, required Map<String, dynamic> updatedPlaceFields}) async {
    final user = await _requireStaff();
    validatePlaceUpdate(updatedPlaceFields);
    final ref = _firestore.collection(FirestoreCollections.places).doc(placeId);
    await _firestore.runTransaction((tx) async {
      final place = await tx.get(ref);
      if (!place.exists) throw StateError('Place no longer exists.');
      _writePlaceAndVerification(tx, ref, place.data()!, updatedPlaceFields, user);
    });
  }

  void _writePlaceAndVerification(Transaction tx,
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> before, Map<String, dynamic> fields, User user) {
    final update = Map<String, dynamic>.from(fields);
    final features = update['accessibility'];
    if (features is Map) {
      final normalized = <String, dynamic>{};
      final previous = before['accessibility'];
      bool anyVerified = false;
      for (final entry in features.entries) {
        final key = entry.key.toString();
        final value = Map<String, dynamic>.from(entry.value as Map);
        final old = previous is Map ? previous[key] : null;
        final changed = old is! Map || old['available'] != value['available'] || old['notes'] != value['notes'];
        final verified = !changed && value['verified'] == true;
        value['verified'] = verified;
        value['lastUpdated'] = FieldValue.serverTimestamp();
        normalized[key] = value;
        anyVerified = anyVerified || verified;
        tx.set(_firestore.collection(FirestoreCollections.verificationRecords)
            .doc('${ref.id}_$key'), {
          'placeId': ref.id, 'feature': key,
          'verifiedBy': user.uid,
          'verifierName': user.displayName ?? user.email ?? 'AccessLink staff',
          'status': verified ? 'verified' : 'unverified',
          'source': 'staff_review',
          'available': value['available'], 'notes': value['notes'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      update['accessibility'] = normalized;
      update['isVerified'] = anyVerified;
    }
    tx.update(ref, {...update, 'updatedAt': FieldValue.serverTimestamp()});
  }

  static void validatePlaceUpdate(Map<String, dynamic> fields) {
    const allowed = {
      'accessibility', 'accessibilityScore', 'isVerified',
      'hasWheelchairAccess', 'hasAccessibleToilet', 'hasElevator',
      'hasAccessibleParking', 'hasTactilePaving', 'hasAudioSupport', 'hasHearingSupport',
      'openingHours', 'contact', 'description',
    };
    if (fields.isEmpty || fields.keys.any((k) => !allowed.contains(k))) {
      throw ArgumentError('Unsupported place update fields.');
    }
    if (fields.containsKey('accessibilityScore')) {
      final score = fields['accessibilityScore'];
      if (score is! int || score < 0 || score > 100) throw ArgumentError('Invalid accessibility score.');
    }
    for (final key in allowed.where((k) => k.startsWith('has') || k == 'isVerified')) {
      if (fields.containsKey(key) && fields[key] is! bool) throw ArgumentError('Invalid $key value.');
    }
    if (fields.containsKey('accessibility')) {
      final features = fields['accessibility'];
      if (features is! Map) throw ArgumentError('Accessibility must be a feature map.');
      const keys = {'wheelchairAccessible','accessibleToilet','elevator','accessibleParking','tactilePaving','audioSupport','hearingSupport'};
      if (features.keys.any((k) => !keys.contains(k))) throw ArgumentError('Unsupported accessibility feature.');
      for (final value in features.values) {
        if (value is! Map || value['available'] is! bool || value['verified'] is! bool ||
            value['notes'] is! String || (value['notes'] as String).length > 2000) {
          throw ArgumentError('Invalid accessibility feature value.');
        }
      }
    }
  }
}
