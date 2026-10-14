import 'package:accesslink/models/search_place.dart';
import 'package:accesslink/screens/search_results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const places = <Map<String, dynamic>>[
    {
      'name': 'Local Park',
      'categoryName': 'Park',
      'latitude': 6.93,
      'longitude': 79.86,
    },
    {
      'name': 'Regional Park',
      'categoryName': 'Park',
      'latitude': 7.1,
      'longitude': 79.86,
    },
    {
      'name': 'Kandy Park',
      'categoryName': 'Park',
      'latitude': 7.29,
      'longitude': 80.63,
    },
    {'name': 'Unknown Park', 'categoryName': 'Park'},
  ];

  testWidgets(
    'nearby excludes distant and ungeolocated places and widens radius',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SearchResultsScreen(
            initialPlaces: places,
            initialNearbyOnly: true,
            initialLocation: defaultSearchLocation,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local Park'), findsOneWidget);
      expect(find.text('Regional Park'), findsNothing);
      expect(find.text('Kandy Park'), findsNothing);
      expect(find.text('Unknown Park'), findsNothing);

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      final radius = tester.widget<Slider>(find.byType(Slider));
      radius.onChanged!(25);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Regional Park'), findsOneWidget);
      expect(find.text('Kandy Park'), findsNothing);
      expect(find.text('Unknown Park'), findsNothing);

      await tester.tap(find.text('Nearest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name').last);
      await tester.pumpAndSettle();
      expect(find.text('Local Park'), findsOneWidget);
      expect(find.text('Regional Park'), findsOneWidget);
      expect(find.text('Kandy Park'), findsNothing);
      expect(find.text('Unknown Park'), findsNothing);
    },
  );
}
