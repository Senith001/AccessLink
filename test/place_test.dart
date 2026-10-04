import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:accesslink/firebase_options.dart';
import 'package:accesslink/services/place_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  test('Fetch places from Firestore', () async {
    final placeService = PlaceService();

    final places = await placeService.getPlaces();

    expect(places, isNotEmpty);
  });
}