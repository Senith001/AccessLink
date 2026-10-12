import 'package:cloud_firestore/cloud_firestore.dart';

class PlacePhoto {
  final String id;
  final String placeId;
  final String uploaderId;
  final String uploaderName;
  final String url;
  final String? storagePath;
  final String caption;
  final DateTime? createdAt;

  const PlacePhoto({
    required this.id,
    required this.placeId,
    required this.uploaderId,
    required this.uploaderName,
    required this.url,
    this.storagePath,
    this.caption = '',
    this.createdAt,
  });

  factory PlacePhoto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PlacePhoto(
      id: doc.id,
      placeId: data['placeId'] as String? ?? '',
      uploaderId: data['uploaderId'] as String? ?? '',
      uploaderName: data['uploaderName'] as String? ?? 'Contributor',
      url: data['url'] as String? ?? '',
      storagePath: data['storagePath'] as String?,
      caption: data['caption'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'uploaderId': uploaderId,
      'uploaderName': uploaderName,
      'url': url,
      if (storagePath != null) 'storagePath': storagePath,
      'caption': caption,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
