import 'package:url_launcher/url_launcher.dart';

class DirectionsService {
  Future<void> openDirections({
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final Uri mapUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$destinationLatitude,$destinationLongitude',
    );

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