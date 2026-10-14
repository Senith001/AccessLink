import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/place.dart';

class MapSearchException implements Exception {
  const MapSearchException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MapPlaceSearchService {
  MapPlaceSearchService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  final Map<String, List<Place>> _searchCache = {};
  final Map<String, Map<String, String>> _tagCache = {};
  void dispose() => _client.close();

  Future<List<Place>> search(
    String text, {
    required double latitude,
    required double longitude,
  }) async {
    if (text.trim().isEmpty) return [];
    final key =
        '${text.trim().toLowerCase()}|${latitude.toStringAsFixed(2)}|${longitude.toStringAsFixed(2)}';
    if (_searchCache.containsKey(key)) return _searchCache[key]!;
    // Coordinates bias ranking; they do not restrict the search area.
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.https('photon.komoot.io', '/api/', {
              'q': text.trim(),
              'limit': '15',
              'countrycode': 'LK',
              'lat': '$latitude',
              'lon': '$longitude',
            }),
          )
          .timeout(const Duration(seconds: 40));
    } on TimeoutException {
      throw const MapSearchException(
        'Search is taking too long. Please press Search to retry.',
      );
    } on http.ClientException {
      throw const MapSearchException(
        'Could not connect to place search. Check your connection and retry.',
      );
    }
    if (response.statusCode != 200) {
      throw MapSearchException(
        response.statusCode == 429
            ? 'Place search is busy. Wait a moment, then retry.'
            : 'Place search is temporarily unavailable. Please retry.',
      );
    }
    final places = _parsePlaces(response);
    if (_searchCache.length >= 50) _searchCache.remove(_searchCache.keys.first);
    _searchCache[key] = places;
    return places;
  }

  Future<List<Place>> nearby({
    required double latitude,
    required double longitude,
    required double radiusInKm,
    required List<String> categories,
    required int limit,
  }) async {
    final latitudeDelta = radiusInKm / 111;
    final longitudeDelta =
        radiusInKm / (111 * math.cos(latitude * math.pi / 180));
    final response = await _client
        .get(
          Uri.https('photon.komoot.io', '/api/', {
            'include': categories,
            'countrycode': 'LK',
            'lat': '$latitude',
            'lon': '$longitude',
            'bbox':
                '${longitude - longitudeDelta},${latitude - latitudeDelta},${longitude + longitudeDelta},${latitude + latitudeDelta}',
            'limit': '${limit.clamp(1, 50)}',
          }),
        )
        .timeout(const Duration(seconds: 40));
    if (response.statusCode != 200) {
      throw Exception('Nearby places unavailable');
    }
    return _parsePlaces(response);
  }

  List<Place> _parsePlaces(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final places = <Place>[];
    for (final feature in (data['features'] as List? ?? [])) {
      final properties = Map<String, dynamic>.from(
        feature['properties'] as Map? ?? {},
      );
      final coordinates = feature['geometry']?['coordinates'];
      if (coordinates is! List ||
          coordinates.length < 2 ||
          coordinates[0] is! num ||
          coordinates[1] is! num) {
        continue;
      }
      final category = (properties['osm_value'] ?? 'Place')
          .toString()
          .replaceAll('_', ' ');
      final type = {
        'N': 'node',
        'W': 'way',
        'R': 'relation',
      }[properties['osm_type']];
      final id = properties['osm_id'];
      if (type == null || id is! num) continue;
      places.add(
        Place(
          id: 'osm_${type}_${id.toInt()}',
          name: (properties['name'] ?? properties['street'] ?? category)
              .toString(),
          address: [
            properties['housenumber'],
            properties['street'],
            properties['city'],
            properties['state'],
            properties['country'],
          ].where((v) => v != null).join(', '),
          categoryName: category,
          location: GeoPoint(
            (coordinates[1] as num).toDouble(),
            (coordinates[0] as num).toDouble(),
          ),
          isVerified: false,
        ),
      );
    }
    return places;
  }

  Future<Map<String, String>> accessibilityTags(Place place) async {
    if (place.osmTags.isNotEmpty) return place.osmTags;
    if (_tagCache.containsKey(place.id)) return _tagCache[place.id]!;
    final match = RegExp(
      r'^osm_(node|way|relation)_(\d+)$',
    ).firstMatch(place.id);
    if (match == null) return {};
    Map<String, dynamic> data;
    try {
      final response = await _client
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: {
              'data':
                  '[out:json][timeout:10];${match[1]}(${match[2]});out tags;',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception('Lookup unavailable');
      data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['remark'] != null) throw Exception('Lookup incomplete');
    } catch (_) {
      // Read the same exact OSM object if the Overpass service fails.
      // This is a single cached lookup, never a nearby-place inference.
      final response = await _client
          .get(
            Uri.parse(
              'https://api.openstreetmap.org/api/0.6/${match[1]}/${match[2]}.json',
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('Accessibility lookup unavailable');
      }
      data = jsonDecode(response.body) as Map<String, dynamic>;
    }
    final elements = data['elements'] as List? ?? [];
    final tags = elements.isEmpty
        ? <String, String>{}
        : Map<String, dynamic>.from(
            elements.first['tags'] as Map? ?? {},
          ).map((key, value) => MapEntry(key, value.toString()));
    if (_tagCache.length >= 100) _tagCache.remove(_tagCache.keys.first);
    _tagCache[place.id] = tags;
    return tags;
  }
}