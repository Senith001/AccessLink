import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Place {
  const Place({
    required this.name,
    required this.category,
    this.address = '',
    this.distance = 'Near you',
    this.accessibilityScore = 'Not rated',
    this.latitude,
    this.longitude,
    required this.icon,
  });

  static Place? fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return fromData(document.data());
  }

  static Place? fromData(Map<String, dynamic> data) {
    final name = data['name'] as String?;
    final category = data['category'] as String?;
    if (name == null || category == null) return null;

    return Place(
      name: name,
      category: category,
      address: data['address'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      icon: iconForCategory(category),
    );
  }

  final String name;
  final String category;
  final String address;
  final String distance;
  final String accessibilityScore;
  final double? latitude;
  final double? longitude;
  final IconData icon;
}

IconData iconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'hospital':
      return Icons.local_hospital;
    case 'park':
      return Icons.park;
    case 'bank':
      return Icons.account_balance;
    case 'library':
      return Icons.local_library;
    default:
      return Icons.place;
  }
}
