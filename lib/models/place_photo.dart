import 'package:cloud_firestore/cloud_firestore.dart';

/// Metadata model for an accessibility photo associated with a place.
class PlacePhoto {
  final String id;
  final String placeId;
  final String uploaderUid;
  final String storagePath;
  final String downloadUrl;
  final String? caption;
  final DateTime createdAt;

  PlacePhoto({
    required this.id,
    required this.placeId,
    required this.uploaderUid,
    required this.storagePath,
    required this.downloadUrl,
    this.caption,
    required this.createdAt,
  });

  factory PlacePhoto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PlacePhoto(
      id: doc.id,
      placeId: data['placeId'] ?? '',
      uploaderUid: data['uploaderUid'] ?? '',
      storagePath: data['storagePath'] ?? '',
      downloadUrl: data['downloadUrl'] ?? '',
      caption: data['caption'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'placeId': placeId,
      'uploaderUid': uploaderUid,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      if (caption != null && caption!.trim().isNotEmpty) 'caption': caption!.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
