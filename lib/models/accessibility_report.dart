import 'package:cloud_firestore/cloud_firestore.dart';

class AccessibilityReport {
  final String id;
  final String placeId;
  final String placeName;
  final String reportedBy;
  final String reporterName;
  final String category;
  final String targetField;
  final String description;
  final String status; // 'pending', 'approved', 'rejected', 'resolved'
  final String? adminNotes;
  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AccessibilityReport({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.reportedBy,
    required this.reporterName,
    required this.category,
    required this.targetField,
    required this.description,
    required this.status,
    this.adminNotes,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isResolved => status == 'resolved';

  String get categoryLabel {
    switch (category) {
      case 'incorrect_accessibility':
        return 'Incorrect accessibility details';
      case 'outdated_info':
        return 'Outdated information';
      case 'inappropriate_content':
        return 'Inappropriate content';
      case 'other':
      default:
        return 'Other';
    }
  }

  factory AccessibilityReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AccessibilityReport.fromMap(doc.id, data);
  }

  factory AccessibilityReport.fromMap(String id, Map<String, dynamic> data) {
    return AccessibilityReport(
      id: id,
      placeId: data['placeId'] as String? ?? '',
      placeName: data['placeName'] as String? ?? 'Unknown Place',
      reportedBy: data['reportedBy'] as String? ?? '',
      reporterName: data['reporterName'] as String? ?? 'Community Contributor',
      category: data['category'] as String? ?? 'incorrect_accessibility',
      targetField: data['targetField'] as String? ?? 'General',
      description: data['description'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      adminNotes: data['adminNotes'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedByName: data['reviewedByName'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'placeName': placeName,
      'reportedBy': reportedBy,
      'reporterName': reporterName,
      'category': category,
      'targetField': targetField,
      'description': description,
      'status': status,
      if (adminNotes != null) 'adminNotes': adminNotes,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedByName != null) 'reviewedByName': reviewedByName,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
