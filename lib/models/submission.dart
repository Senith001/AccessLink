import 'package:cloud_firestore/cloud_firestore.dart';

enum SubmissionStatus { pending, approved, rejected }

enum SubmissionType { photo, accessibility }

enum AccessibilityKind { newFeature, update }

class PhotoSubmission {
  const PhotoSubmission({
    this.id,
    required this.type,
    required this.placeId,
    required this.placeName,
    required this.submittedBy,
    required this.submitterName,
    required this.cloudinaryPublicId,
    this.cloudinaryVersion,
    required this.status,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory PhotoSubmission.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) throw StateError('Document data is null');

    return PhotoSubmission(
      id: snapshot.id,
      type: SubmissionType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => SubmissionType.photo,
      ),
      placeId: data['placeId'] ?? '',
      placeName: data['placeName'] ?? '',
      submittedBy: data['submittedBy'] ?? '',
      submitterName: data['submitterName'] ?? '',
      cloudinaryPublicId: data['cloudinaryPublicId'] as String? ?? '',
      cloudinaryVersion: data['cloudinaryVersion']?.toString(),
      status: SubmissionStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => SubmissionStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedBy: data['reviewedBy'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'],
    );
  }

  static PhotoSubmission? fromData(Map<String, dynamic> data, {String? id}) {
    try {
      // Require essential fields to be present
      if (data['placeId'] == null || data['placeName'] == null || data['submittedBy'] == null) {
        return null;
      }
      
      return PhotoSubmission(
        id: id,
        type: SubmissionType.values.firstWhere(
          (t) => t.name == data['type'],
          orElse: () => SubmissionType.photo,
        ),
        placeId: data['placeId'] ?? '',
        placeName: data['placeName'] ?? '',
        submittedBy: data['submittedBy'] ?? '',
        submitterName: data['submitterName'] ?? '',
        cloudinaryPublicId: data['cloudinaryPublicId'] as String? ?? '',
        cloudinaryVersion: data['cloudinaryVersion']?.toString(),
        status: SubmissionStatus.values.firstWhere(
          (s) => s.name == data['status'],
          orElse: () => SubmissionStatus.pending,
        ),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        reviewedBy: data['reviewedBy'],
        reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
        rejectionReason: data['rejectionReason'],
      );
    } catch (e) {
      return null;
    }
  }

  final String? id;
  final SubmissionType type;
  final String placeId;
  final String placeName;
  final String submittedBy;
  final String submitterName;
  final String cloudinaryPublicId;
  final String? cloudinaryVersion;
  final SubmissionStatus status;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  // TEMPORARY: Deprecated compatibility getters for legacy code.
  // These will be removed in Phase 4-6 when calling code is updated.
  @Deprecated('Use cloudinaryPublicId instead. This field will be removed in Phase 4-6.')
  String get imageUrl => '';
  
  @Deprecated('Use cloudinaryPublicId instead. This field will be removed in Phase 4-6.')
  String get storagePath => '';

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'placeId': placeId,
      'placeName': placeName,
      'submittedBy': submittedBy,
      'submitterName': submitterName,
      'cloudinaryPublicId': cloudinaryPublicId,
      if (cloudinaryVersion != null) 'cloudinaryVersion': cloudinaryVersion,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
  }
}

class AccessibilitySubmission {
  const AccessibilitySubmission({
    this.id,
    required this.type,
    required this.placeId,
    required this.placeName,
    required this.submittedBy,
    required this.submitterName,
    required this.kind,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory AccessibilitySubmission.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) throw StateError('Document data is null');

    return AccessibilitySubmission(
      id: snapshot.id,
      type: SubmissionType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => SubmissionType.accessibility,
      ),
      placeId: data['placeId'] ?? '',
      placeName: data['placeName'] ?? '',
      submittedBy: data['submittedBy'] ?? '',
      submitterName: data['submitterName'] ?? '',
      kind: AccessibilityKind.values.firstWhere(
        (k) => k.name == data['kind'],
        orElse: () => AccessibilityKind.update,
      ),
      payload: Map<String, Map<String, dynamic>>.from(
        data['payload'] ?? <String, Map<String, dynamic>>{},
      ),
      status: SubmissionStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => SubmissionStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedBy: data['reviewedBy'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'],
    );
  }

  static AccessibilitySubmission? fromData(Map<String, dynamic> data, {String? id}) {
    try {
      // Require essential fields to be present
      if (data['placeId'] == null || data['placeName'] == null || data['submittedBy'] == null) {
        return null;
      }
      
      return AccessibilitySubmission(
        id: id,
        type: SubmissionType.values.firstWhere(
          (t) => t.name == data['type'],
          orElse: () => SubmissionType.accessibility,
        ),
        placeId: data['placeId'] ?? '',
        placeName: data['placeName'] ?? '',
        submittedBy: data['submittedBy'] ?? '',
        submitterName: data['submitterName'] ?? '',
        kind: AccessibilityKind.values.firstWhere(
          (k) => k.name == data['kind'],
          orElse: () => AccessibilityKind.update,
        ),
        payload: Map<String, Map<String, dynamic>>.from(
          data['payload'] ?? <String, Map<String, dynamic>>{},
        ),
        status: SubmissionStatus.values.firstWhere(
          (s) => s.name == data['status'],
          orElse: () => SubmissionStatus.pending,
        ),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        reviewedBy: data['reviewedBy'],
        reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
        rejectionReason: data['rejectionReason'],
      );
    } catch (e) {
      return null;
    }
  }

  final String? id;
  final SubmissionType type;
  final String placeId;
  final String placeName;
  final String submittedBy;
  final String submitterName;
  final AccessibilityKind kind;
  final Map<String, Map<String, dynamic>> payload; // 7 features each {available,notes}
  final SubmissionStatus status;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'placeId': placeId,
      'placeName': placeName,
      'submittedBy': submittedBy,
      'submitterName': submitterName,
      'kind': kind.name,
      'payload': payload,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
  }
}