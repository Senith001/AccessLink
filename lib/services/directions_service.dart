import 'package:url_launcher/url_launcher.dart';

import '../models/travel_mode.dart';

class DirectionsService {
  Uri buildDirectionsUri({
    required double destinationLatitude,
    required double destinationLongitude,
    required TravelMode travelMode,
    double? originLatitude,
    double? originLongitude,
  }) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$destinationLatitude,$destinationLongitude',
      'travelmode': travelMode.mapsValue,
      if (originLatitude != null && originLongitude != null)
        'origin': '$originLatitude,$originLongitude',
    });
  }

  Future<void> openDirections({
    required double destinationLatitude,
    required double destinationLongitude,
    required TravelMode travelMode,
    double? originLatitude,
    double? originLongitude,
  }) async {
    final mapUri = buildDirectionsUri(
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      travelMode: travelMode,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
    );

    if (!await launchUrl(mapUri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open map directions');
    }
  }
}