import 'package:accesslink/screens/search_results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final places = <Map<String, dynamic>>[
    for (final city in [
      'Battaramulla',
      'Colombo',
      'Galle',
      'Gampaha',
      'Jaffna',
      'Kandy',
      'Kurunegala',
      'Malabe',
      'Matara',
      'Negombo',
      'Nugegoda',
    ])
      {'name': '$city Park', 'categoryName': 'Park', 'city': city},
  ];

  testWidgets('areas expand and collapse while keeping the selection visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SearchResultsScreen(initialPlaces: places)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Malabe'), findsNothing);
    await tester.ensureVisible(find.text('Show more (5)'));
    await tester.tap(find.text('Show more (5)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Malabe'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Malabe'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show less'));
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Search district or city'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Malabe'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Malabe'))
          .selected,
      isTrue,
    );
    expect(find.widgetWithText(ChoiceChip, 'Matara'), findsNothing);
    expect(find.text('Show more (5)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter can search and select an area beyond the first eight', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SearchResultsScreen(initialPlaces: places)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    final areaSearch = find.widgetWithText(
      TextField,
      'Search district or city',
    );
    await tester.ensureVisible(areaSearch);
    await tester.enterText(areaSearch, 'mAtArA');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Matara'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Colombo'), findsNothing);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Matara'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Matara'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Apply'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Matara Park'), findsOneWidget);
    expect(find.text('Colombo Park'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('area picker includes cities beyond the first eight', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SearchResultsScreen(
          initialPlaces: [
            ...places,
            {'name': 'Z Town Park', 'categoryName': 'Park', 'city': 'Z Town'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose area'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search district or city'),
      'Z Town',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Z Town'));
    await tester.pumpAndSettle();
    expect(find.text('Z Town Park'), findsOneWidget);
    expect(find.text('No accessible places found'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
