import 'package:url_launcher/url_launcher.dart';

class DirectionsService {
  Future<void> openDirections({
    required double destinationLatitude,
    required double destinationLongitude,
    double? originLatitude,
    double? originLongitude,
  }) async {
    final buffer = StringBuffer('https://www.google.com/maps/dir/?api=1');
    if (originLatitude != null && originLongitude != null) {
      buffer.write('&origin=${originLatitude.toString()},${originLongitude.toString()}');
    }
    buffer.write('&destination=${destinationLatitude.toString()},${destinationLongitude.toString()}');

    final Uri mapUri = Uri.parse(buffer.toString());

    if (await canLaunchUrl(mapUri)) {
      await launchUrl(
        mapUri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      throw Exception('Could not open map directions');
    }
  }
}