import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class TravelTimeService {
  final Distance _distance = const Distance();

  double calculateDistanceKm({
    required double startLatitude,
    required double startLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) {
    final distanceInMeters = _distance.as(
      LengthUnit.Meter,
      LatLng(startLatitude, startLongitude),
      LatLng(destinationLatitude, destinationLongitude),
    );

    return distanceInMeters / 1000;
  }

  int calculateEstimatedTravelTime({
    required double distanceKm,
    double averageSpeedKmH = 40,
  }) {
    if (distanceKm <= 0 || averageSpeedKmH <= 0) {
      return 0;
    }

    final timeInHours = distanceKm / averageSpeedKmH;
    final timeInMinutes = timeInHours * 60;

    return timeInMinutes.ceil();
  }

  /// Attempts to fetch realistic travel time in minutes using OSRM public API.
  /// Falls back to the simple distance/average-speed estimate on failure.
  ///
  /// Note: `router.project-osrm.org` is a public demo server — use a hosted
  /// routing service (OpenRouteService, GraphHopper, Mapbox, or self-hosted
  /// OSRM) for production and higher reliability.
  Future<int> fetchTravelTimeMinutes({
    required double startLatitude,
    required double startLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${startLongitude.toString()},${startLatitude.toString()};'
        '${destinationLongitude.toString()},${destinationLatitude.toString()}'
        '?overview=false&alternatives=false&steps=false',
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final jsonBody = jsonDecode(resp.body) as Map<String, dynamic>;
        final routes = jsonBody['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final durationSec = (route['duration'] as num?)?.toDouble();
          if (durationSec != null) {
            final minutes = (durationSec / 60).ceil();
            return minutes;
          }
        }
      }
    } catch (_) {
      // ignore and fallback
    }

    // Fallback: use straight-line distance divided by average speed
    final distanceKm = calculateDistanceKm(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
    );

    return calculateEstimatedTravelTime(distanceKm: distanceKm);
  }
}