import 'package:flutter_test/flutter_test.dart';
import 'package:accesslink/services/place_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PlaceService returns fallback places when offline', () async {
    final placeService = PlaceService();

    final places = placeService.getFallbackPlaces();

    expect(places, isNotEmpty);
    expect(places.first.name, isNotEmpty);
    expect(places.first.isVerified, isTrue);
  });
}
