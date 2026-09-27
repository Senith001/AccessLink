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
}