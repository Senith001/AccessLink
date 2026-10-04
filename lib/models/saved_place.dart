import 'package:flutter/material.dart';

import 'search_place.dart';

class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.name,
    required this.category,
    this.address = '',
    this.city = '',
    this.district = '',
    this.latitude,
    this.longitude,
    this.accessibilityFeatures = const {},
  });

  factory SavedPlace.fromPlace(SearchPlace place) {
    return SavedPlace(
      id: place.id,
      name: place.name,
      category: place.category,
      address: place.address,
      city: place.city,
      district: place.district,
      latitude: place.latitude,
      longitude: place.longitude,
      accessibilityFeatures: place.accessibilityFeatures,
    );
  }

  static SavedPlace? fromData(Map<String, dynamic> data, {String? id}) {
    final place = SearchPlace.fromData({
      ...data,
      if (data['name'] == null && data['placeName'] != null)
        'name': data['placeName'],
    }, id: id);
    if (place == null) return null;
    return SavedPlace.fromPlace(place);
  }

  final String id;
  final String name;
  final String category;
  final String address;
  final String city;
  final String district;
  final double? latitude;
  final double? longitude;
  final Set<String> accessibilityFeatures;

  IconData get icon => iconForSearchCategory(category);

  String get locationLabel {
    if (city.isNotEmpty && district.isNotEmpty) return '$city, $district';
    if (city.isNotEmpty) return city;
    if (district.isNotEmpty) return district;
    return address;
  }

  Map<String, dynamic> toData() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'address': address,
      'city': city,
      'district': district,
      'latitude': latitude,
      'longitude': longitude,
      'accessibilityFeatures': accessibilityFeatures.toList()..sort(),
      'placeId': id,
      'placeName': name,
    };
  }
}
