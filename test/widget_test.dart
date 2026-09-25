// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesslink/screens/home_screen.dart';
import 'package:accesslink/screens/search_results_screen.dart';

void main() {
  testWidgets('home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Accessibility map'), findsOneWidget);
  });

  testWidgets('search displays matching places', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          initialPlaces: [
            {
              'name': 'City Hospital',
              'category': 'Hospital',
            },
          ],
        ),
      ),
    );

    await tester.tap(find.text('Search accessible places'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hospital');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('City Hospital'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('City Hospital'), findsOneWidget);
    expect(find.text('Green Park'), findsNothing);
  });

  testWidgets('search displays a no-results message',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          initialPlaces: [
            {
              'name': 'Central Park',
              'category': 'Park',
            },
          ],
        ),
      ),
    );

    await tester.tap(find.text('Search accessible places'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'library');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('No accessible places found'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('No accessible places found'), findsOneWidget);
  });

  testWidgets('search results screen displays matching places',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SearchResultsScreen(
          initialQuery: 'hospital',
          initialPlaces: [
            {
              'name': 'City Hospital',
              'category': 'Hospital',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search results'), findsOneWidget);
    expect(find.text('City Hospital'), findsOneWidget);
  });

  testWidgets('search results screen handles no matches',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SearchResultsScreen(
          initialQuery: 'cinema',
          initialPlaces: [
            {
              'name': 'Central Park',
              'category': 'Park',
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No accessible places found'), findsOneWidget);
  });
}