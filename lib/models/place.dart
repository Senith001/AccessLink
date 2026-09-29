import 'package:cloud_firestore/cloud_firestore.dart';

class Place {
  final String id;
  final String name;
  final String address;
  final String categoryName;
  final GeoPoint location;
  final bool isVerified;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.categoryName,
    required this.location,
    required this.isVerified,
  });

  factory Place.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    return Place(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      categoryName: data['categoryName'] ?? '',
      location: data['location'] as GeoPoint,
      isVerified: data['isVerified'] ?? false,
    );
  }

  double get latitude => location.latitude;

  double get longitude => location.longitude;
}