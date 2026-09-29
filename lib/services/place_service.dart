import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/place.dart';

class PlaceService {
  static const double _defaultLatitude = 6.9271;
  static const double _defaultLongitude = 79.8612;

  static const Map<String, List<String>> _categoryMap = {
    'All': ['restaurant', 'toilets', 'hospital', 'pharmacy', 'fuel', 'bank', 'supermarket', 'bus_stop', 'school', 'parking', 'hotel'],
    'Restaurants': ['restaurant'],
    'Hospitals': ['hospital'],
    'Hotels': ['hotel'],
    'Washrooms': ['toilets'],
    'Fuel': ['fuel'],
    'Pharmacies': ['pharmacy'],
    'Banks': ['bank'],
    'Supermarkets': ['supermarket'],
    'Bus Stops': ['bus_stop'],
    'Schools': ['school'],
    'Parking': ['parking'],
  };

  static const List<Map<String, dynamic>> _fallbackPlaces = [
    {'name': 'Colombo City Hospital', 'address': 'Galle Road, Colombo', 'categoryName': 'Hospital', 'lat': 6.9271, 'lng': 79.8612},
    {'name': 'Cinnamon Grand', 'address': 'Colombo 03', 'categoryName': 'Hotel', 'lat': 6.9271, 'lng': 79.8487},
    {'name': 'Laksala', 'address': 'Kollupitiya', 'categoryName': 'Supermarket', 'lat': 6.9054, 'lng': 79.8533},
    {'name': 'Avenue Hospital', 'address': 'Ward Place', 'categoryName': 'Hospital', 'lat': 6.9034, 'lng': 79.8746},
    {'name': 'Colombo Public Toilet', 'address': 'Fort', 'categoryName': 'Washroom', 'lat': 6.9355, 'lng': 79.8437},
    {'name': 'Kingsbury Restaurant', 'address': 'Marine Drive', 'categoryName': 'Restaurant', 'lat': 6.9255, 'lng': 79.8407},
    {'name': 'Cargills Food City', 'address': 'Borella', 'categoryName': 'Supermarket', 'lat': 6.9138, 'lng': 79.8789},
    {'name': 'Bocca Restaurant', 'address': 'Colombo 07', 'categoryName': 'Restaurant', 'lat': 6.9068, 'lng': 79.8544},
  ];

  Future<List<Place>> getPlaces({
    double? latitude,
    double? longitude,
    double radiusInKm = 3,
    String category = 'All',
  }) async {
    final lat = latitude ?? _defaultLatitude;
    final lon = longitude ?? _defaultLongitude;
    final radiusInMeters = (radiusInKm * 1000).round();

    final selectedTags = _categoryMap[category] ?? _categoryMap['All']!;
    final places = <Place>[];

    try {
      final futures = selectedTags.map((tag) => _fetchOverpassTags(
            latitude: lat,
            longitude: lon,
            radiusInMeters: radiusInMeters,
            tag: tag,
          ));

      final results = await Future.wait(futures).timeout(const Duration(seconds: 12));

      for (final r in results) {
        places.addAll(r);
      }
    } catch (_) {
      // If parallel fetch fails/timeout, return empty list so fallback is used below.
    }

    if (places.isNotEmpty) {
      return places;
    }

    return _fallbackPlaces
        .map(
          (item) => Place(
            id: 'fallback_${item['name']}',
            name: item['name'] as String,
            address: item['address'] as String,
            categoryName: item['categoryName'] as String,
            location: GeoPoint(
              item['lat'] as double,
              item['lng'] as double,
            ),
            isVerified: true,
          ),
        )
        .toList();
  }

  /// Public accessor for the fallback places as `Place` objects.
  List<Place> getFallbackPlaces() {
    return _fallbackPlaces
        .map(
          (item) => Place(
            id: 'fallback_${item['name']}',
            name: item['name'] as String,
            address: item['address'] as String,
            categoryName: item['categoryName'] as String,
            location: GeoPoint(
              item['lat'] as double,
              item['lng'] as double,
            ),
            isVerified: true,
          ),
        )
        .toList();
  }

  Future<List<Place>> _fetchOverpassTags({
    required double latitude,
    required double longitude,
    required int radiusInMeters,
    required String tag,
  }) async {
    final query = '''
      [out:json][timeout:10];
      (
        node["amenity"="$tag"](around:$radiusInMeters,$latitude,$longitude);
        way["amenity"="$tag"](around:$radiusInMeters,$latitude,$longitude);
        node["shop"="$tag"](around:$radiusInMeters,$latitude,$longitude);
        way["shop"="$tag"](around:$radiusInMeters,$latitude,$longitude);
        node["tourism"="$tag"](around:$radiusInMeters,$latitude,$longitude);
        way["tourism"="$tag"](around:$radiusInMeters,$latitude,$longitude);
        node["highway"="$tag"](around:$radiusInMeters,$latitude,$longitude);
        way["highway"="$tag"](around:$radiusInMeters,$latitude,$longitude);
      );
      out center;
    ''';

    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse('https://overpass-api.de/api/interpreter?data=$encodedQuery');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = decoded['elements'] as List<dynamic>? ?? const [];
      final places = <Place>[];

      for (final element in elements) {
        final map = Map<String, dynamic>.from(element as Map<dynamic, dynamic>);
        final tags = Map<String, dynamic>.from(map['tags'] ?? const {});

        final latValue = map['lat'] ?? (map['center'] is Map ? map['center']['lat'] : null);
        final lonValue = map['lon'] ?? (map['center'] is Map ? map['center']['lon'] : null);

        if (latValue == null || lonValue == null) {
          continue;
        }

        final categoryValue =
            tags['amenity'] ??
            tags['tourism'] ??
            tags['shop'] ??
            tags['highway'] ??
            'public place';

        final placeName =
            (tags['name'] ?? tags['brand'] ?? tags['operator'] ?? 'Public place')
                .toString();
        final address = (tags['addr:street'] ?? 'OpenStreetMap place').toString();

        places.add(
          Place(
            id: 'osm_${map['id']}',
            name: placeName,
            address: address,
            categoryName: _formatCategory(categoryValue.toString()),
            location: GeoPoint(latValue as double, lonValue as double),
            isVerified: true,
          ),
        );
      }

      return places;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Place>> getPlacesByCategory(String category) async {
    final normalizedCategory = category.trim();
    if (normalizedCategory.isEmpty || normalizedCategory.toLowerCase() == 'all') {
      return getPlaces();
    }

    final mappedCategory = _mapCategoryNameToApiKey(normalizedCategory);
    return getPlaces(category: mappedCategory);
  }

  String _mapCategoryNameToApiKey(String category) {
    final lower = category.toLowerCase();

    if (lower.contains('rest')) return 'Restaurants';
    if (lower.contains('hospital')) return 'Hospitals';
    if (lower.contains('hotel')) return 'Hotels';
    if (lower.contains('wash') || lower.contains('toilet')) return 'Washrooms';
    if (lower.contains('fuel')) return 'Fuel';
    if (lower.contains('pharm')) return 'Pharmacies';
    if (lower.contains('bank')) return 'Banks';
    if (lower.contains('super')) return 'Supermarkets';
    if (lower.contains('bus')) return 'Bus Stops';
    if (lower.contains('school')) return 'Schools';
    if (lower.contains('park')) return 'Parking';

    return 'All';
  }

  String _formatCategory(String value) {
    final cleaned = value.replaceAll('_', ' ');
    final words = cleaned.split(' ');

    return words
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}