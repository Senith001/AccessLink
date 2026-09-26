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
    this.accessibilityFeatures = const {},
    required this.icon,
  });

  static Place? fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return fromData(document.data());
  }

  static Place? fromData(Map<String, dynamic> data) {
    final name = data['name'] as String?;
    final category =
        data['category'] as String? ??
        data['categoryName'] as String? ??
        'Place';
    if (name == null) return null;

    final location = data['location'];
    final latitude =
        data['latitude'] as num? ??
        (location is GeoPoint ? location.latitude : null);
    final longitude =
        data['longitude'] as num? ??
        (location is GeoPoint ? location.longitude : null);

    return Place(
      name: name.trim(),
      category: category,
      address: data['address'] as String? ?? data['city'] as String? ?? '',
      latitude: latitude?.toDouble(),
      longitude: longitude?.toDouble(),
      accessibilityFeatures: _readAccessibilityFeatures(data),
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
  final Set<String> accessibilityFeatures;
  final IconData icon;
}

Set<String> _readAccessibilityFeatures(Map<String, dynamic> data) {
  final rawFeatures =
      data['accessibility'] ??
      data['accessibilityFeatures'] ??
      data['accessibility_features'] ??
      data['features'];

  if (rawFeatures is List) {
    return rawFeatures.whereType<String>().map(_normaliseFeature).toSet();
  }

  final features = <String>{};

  if (rawFeatures is Map) {
    for (final entry in rawFeatures.entries) {
      final value = entry.value;
      if (value == true || (value is Map && value['available'] == true)) {
        features.add(_normaliseFeature(entry.key.toString()));
      }
    }
  }

  features.addAll({
    for (final feature in accessibilityFeatureNames)
      if (data[feature] == true) feature,
  });
  features.addAll({
    if (data['hasWheelchairAccess'] == true) 'wheelchairaccessible',
    if (data['hasAccessibleParking'] == true) 'accessibleparking',
    if (data['hasAccessibleToilet'] == true) 'accessibletoilet',
    if (data['hasAudioSupport'] == true) 'audiosupport',
    if (data['hasElevator'] == true) 'elevator',
    if (data['hasHearingSupport'] == true) 'hearingsupport',
    if (data['hasTactilePaving'] == true) 'tactilepaving',
  });

  return features;
}

String _normaliseFeature(String value) =>
    value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

const accessibilityFeatureNames = [
  'accessibleparking',
  'accessibletoilet',
  'audiosupport',
  'elevator',
  'hearingsupport',
  'tactilepaving',
  'wheelchairaccessible',
];

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
