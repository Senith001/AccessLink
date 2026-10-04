import 'package:geolocator/geolocator.dart';

import '../models/search_place.dart';

class LocationResult {
  const LocationResult._({this.location, this.errorMessage});

  const LocationResult.success(SearchPlaceLocation location)
    : this._(location: location);

  const LocationResult.failure(String message) : this._(errorMessage: message);

  final SearchPlaceLocation? location;
  final String? errorMessage;

  bool get hasLocation => location != null;
}

class LocationService {
  const LocationService();

  Future<LocationResult> currentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult.failure(
        'Turn on location services to find places near you.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocationResult.failure(
        'Location permission is needed to show nearby places.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failure(
        'Location permission is blocked. Enable it in settings to find nearby places.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return LocationResult.success(
      SearchPlaceLocation(
        label: 'Your Location',
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );
  }
}
