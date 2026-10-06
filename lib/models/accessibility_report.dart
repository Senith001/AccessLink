import 'package:cloud_firestore/cloud_firestore.dart';

/// Status lifecycle for an accessibility report.
enum ReportStatus { pending, approved, rejected }

/// Represents a user-submitted report about incorrect accessibility
/// information for a place.
class AccessibilityReport {
  final String id;
  final String placeId;
  final String placeName;
  final String reporterUid;
  final String reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? reviewerUid;
  final DateTime? reviewedAt;
  final String? correctedInfo;

  AccessibilityReport({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.reporterUid,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reviewerUid,
    this.reviewedAt,
    this.correctedInfo,
  });

  factory AccessibilityReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return AccessibilityReport(
      id: doc.id,
      placeId: data['placeId'] ?? '',
      placeName: data['placeName'] ?? '',
      reporterUid: data['reporterUid'] ?? '',
      reason: data['reason'] ?? '',
      status: _parseStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewerUid: data['reviewerUid'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      correctedInfo: data['correctedInfo'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'placeId': placeId,
      'placeName': placeName,
      'reporterUid': reporterUid,
      'reason': reason,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewerUid != null) 'reviewerUid': reviewerUid,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (correctedInfo != null) 'correctedInfo': correctedInfo,
    };
  }

  static ReportStatus _parseStatus(String? value) {
    switch (value) {
      case 'approved':
        return ReportStatus.approved;
      case 'rejected':
        return ReportStatus.rejected;
      default:
        return ReportStatus.pending;
    }
  }
}
