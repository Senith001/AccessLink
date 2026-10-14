import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationRecord {
  final String id;
  final String placeId;
  final String
  feature; // 'place' or specific feature key like 'wheelchairAccessible'
  final String verifiedBy;
  final String verifierName;
  final String status; // 'verified'
  final String
  source; // e.g. 'site_visit', 'certified_audit', 'authority_inspection'
  final DateTime? createdAt;

  const VerificationRecord({
    required this.id,
    required this.placeId,
    required this.feature,
    required this.verifiedBy,
    required this.verifierName,
    required this.status,
    required this.source,
    this.createdAt,
  });

  String get publicAuthorityDescription {
    switch (source) {
      case 'staff_review':
        return 'Reviewed by authorized AccessLink staff';
      case 'site_visit':
        return 'Verified via on-site accessibility inspection';
      case 'certified_audit':
        return 'Verified by Certified Accessibility Auditor';
      case 'authority_inspection':
        return 'Verified by Municipal Accessibility Authority';
      default:
        return 'Verified by AccessLink Accessibility Team';
    }
  }

  factory VerificationRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return VerificationRecord(
      id: doc.id,
      placeId: data['placeId'] as String? ?? '',
      feature: data['feature'] as String? ?? 'place',
      verifiedBy: data['verifiedBy'] as String? ?? '',
      verifierName: data['verifierName'] as String? ?? 'Verifier not specified',
      status: data['status'] as String? ?? 'unverified',
      source: data['source'] as String? ?? 'unknown',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'feature': feature,
      'verifiedBy': verifiedBy,
      'verifierName': verifierName,
      'status': status,
      'source': source,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
