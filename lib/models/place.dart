import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Place {
  const Place({
    required this.name,
    required this.category,
    this.address = '',
    this.city = '',
    this.district = '',
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
      city: data['city'] as String? ?? '',
      district: data['district'] as String? ?? '',
      latitude: latitude?.toDouble(),
      longitude: longitude?.toDouble(),
      accessibilityFeatures: _readAccessibilityFeatures(data),
      icon: iconForCategory(category),
    );
  }

  final String name;
  final String category;
  final String address;
  final String city;
  final String district;
  final String distance;
  final String accessibilityScore;
  final double? latitude;
  final double? longitude;
  final Set<String> accessibilityFeatures;
  final IconData icon;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get locationLabel {
    if (city.isNotEmpty && district.isNotEmpty) return '$city, $district';
    if (city.isNotEmpty) return city;
    if (district.isNotEmpty) return district;
    return address;
  }

  Place copyWith({String? distance, String? accessibilityScore}) {
    return Place(
      name: name,
      category: category,
      address: address,
      city: city,
      district: district,
      distance: distance ?? this.distance,
      accessibilityScore: accessibilityScore ?? this.accessibilityScore,
      latitude: latitude,
      longitude: longitude,
      accessibilityFeatures: accessibilityFeatures,
      icon: icon,
    );
  }

  Place withDistanceFrom(PlaceLocation location) {
    final kilometres = distanceFrom(location);
    if (kilometres == null) return this;

    return copyWith(distance: formatDistance(kilometres));
  }

  double? distanceFrom(PlaceLocation location) {
    final placeLatitude = latitude;
    final placeLongitude = longitude;
    if (placeLatitude == null || placeLongitude == null) return null;

    return distanceBetweenInKm(
      location.latitude,
      location.longitude,
      placeLatitude,
      placeLongitude,
    );
  }
}

class PlaceLocation {
  const PlaceLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

const defaultSearchLocation = PlaceLocation(
  label: 'Current Location',
  latitude: 6.9271,
  longitude: 79.8612,
);

List<Place> placesSortedByDistance(
  Iterable<Place> places, {
  PlaceLocation from = defaultSearchLocation,
}) {
  final sortedPlaces = places
      .map((place) => place.withDistanceFrom(from))
      .toList();
  sortedPlaces.sort((first, second) {
    final firstDistance = first.distanceFrom(from);
    final secondDistance = second.distanceFrom(from);
    if (firstDistance == null && secondDistance == null) return 0;
    if (firstDistance == null) return 1;
    if (secondDistance == null) return -1;
    return firstDistance.compareTo(secondDistance);
  });
  return sortedPlaces;
}

double distanceBetweenInKm(
  double startLatitude,
  double startLongitude,
  double endLatitude,
  double endLongitude,
) {
  const earthRadiusKm = 6371.0;
  final latitudeDistance = _degreesToRadians(endLatitude - startLatitude);
  final longitudeDistance = _degreesToRadians(endLongitude - startLongitude);
  final startLatitudeRadians = _degreesToRadians(startLatitude);
  final endLatitudeRadians = _degreesToRadians(endLatitude);

  final haversine =
      math.pow(math.sin(latitudeDistance / 2), 2) +
      math.cos(startLatitudeRadians) *
          math.cos(endLatitudeRadians) *
          math.pow(math.sin(longitudeDistance / 2), 2);
  final centralAngle =
      2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));

  return earthRadiusKm * centralAngle;
}

String formatDistance(double kilometres) {
  if (kilometres < 1) {
    return '${(kilometres * 1000).round()} m away';
  }
  if (kilometres < 10) {
    return '${kilometres.toStringAsFixed(1)} km away';
  }
  return '${kilometres.round()} km away';
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180;

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
