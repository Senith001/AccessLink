import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:accesslink/models/place_detail.dart';
import 'package:accesslink/widgets/place/rating_stars.dart';
import 'package:accesslink/widgets/place/verified_badge.dart';
import 'package:accesslink/widgets/place/accessibility_feature_tile.dart';
import 'package:accesslink/widgets/place/photo_gallery.dart';
import 'package:accesslink/widgets/place/contact_tile.dart';
import 'package:accesslink/widgets/place/opening_hours_tile.dart';
import 'package:accesslink/widgets/place/place_action_buttons.dart';

void main() {
  group('RatingStars Widget', () {
    testWidgets('shows "No ratings yet" when count is 0', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RatingStars(average: 0, count: 0),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No ratings yet'), findsOneWidget);
    });

    testWidgets('shows rating average and count when available', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RatingStars(average: 4.5, count: 10),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('4.5'), findsOneWidget);
      expect(find.textContaining('(10)'), findsOneWidget);
    });
  });

  group('VerifiedBadge Widget', () {
    testWidgets('shows "Verified" when isVerified is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerifiedBadge(isVerified: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Verified'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('shows "Not verified" when isVerified is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerifiedBadge(isVerified: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Not verified'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('shows "Not verified" for legacy docs without placeVerified', (WidgetTester tester) async {
      // This test simulates PlaceDetail with placeVerified=false (default for legacy docs)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerifiedBadge(isVerified: false), // This would be place.placeVerified
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Not verified'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  group('AccessibilityFeatureTile Widget', () {
    testWidgets('shows "Available" for available feature', (WidgetTester tester) async {
      const feature = AccessibilityFeature(
        available: true,
        notes: '',
        verified: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibilityFeatureTile(
              icon: Icons.accessible,
              label: 'Wheelchair Access',
              feature: feature,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('shows "Not available" for unavailable feature', (WidgetTester tester) async {
      const feature = AccessibilityFeature(
        available: false,
        notes: '',
        verified: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibilityFeatureTile(
              icon: Icons.accessible,
              label: 'Wheelchair Access',
              feature: feature,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Not available'), findsOneWidget);
    });

    testWidgets('shows unverified text for available but unverified feature', (WidgetTester tester) async {
      const feature = AccessibilityFeature(
        available: true,
        notes: '',
        verified: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibilityFeatureTile(
              icon: Icons.accessible,
              label: 'Wheelchair Access',
              feature: feature,
            ),
          ),
        ),
      );
      await tester.pump();

      // Should preserve existing text for test compatibility
      expect(find.textContaining('unverified'), findsOneWidget);
      // Should also show the new verification chip
      expect(find.text('Unverified'), findsOneWidget);
    });

    testWidgets('shows verified chip for available and verified feature', (WidgetTester tester) async {
      const feature = AccessibilityFeature(
        available: true,
        notes: '',
        verified: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibilityFeatureTile(
              icon: Icons.accessible,
              label: 'Wheelchair Access',
              feature: feature,
            ),
          ),
        ),
      );
      await tester.pump();

      // Should preserve existing text for test compatibility
      expect(find.text('Available'), findsOneWidget);
      // Should also show the new verification chip
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('does not show verification chip for unavailable feature', (WidgetTester tester) async {
      const feature = AccessibilityFeature(
        available: false,
        notes: '',
        verified: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccessibilityFeatureTile(
              icon: Icons.accessible,
              label: 'Wheelchair Access',
              feature: feature,
            ),
          ),
        ),
      );
      await tester.pump();

      // Should preserve existing text for test compatibility
      expect(find.text('Not available'), findsOneWidget);
      // Should NOT show verification chip for unavailable features
      expect(find.text('Verified'), findsNothing);
      expect(find.text('Unverified'), findsNothing);
    });

    testWidgets('handles long label without vertical character wrapping', (WidgetTester tester) async {
      // Set realistic phone width constraints
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      const feature = AccessibilityFeature(
        available: true,
        verified: false,
        notes: 'Ramps and wide doorways at main entrance',
        lastUpdated: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: AccessibilityFeatureTile(
                icon: Icons.accessible,
                label: 'Wheelchair Accessible',
                feature: feature,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Key assertion: label should be rendered as a single string, not per-character
      expect(find.text('Wheelchair Accessible'), findsOneWidget);
      
      // Status text should be present
      expect(find.text('Available (unverified)'), findsOneWidget);
      
      // No overflow exception should occur
      expect(tester.takeException(), isNull);

      // Reset view size
      addTearDown(() {
        tester.view.reset();
      });
    });
  });

  group('PhotoGallery Widget', () {
    testWidgets('shows "No photos available" when photos list is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhotoGallery(photos: []),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No photos available'), findsOneWidget);
    });
  });

  group('ContactTile Widget', () {
    testWidgets('shows "Contact details not available" for empty contact', (WidgetTester tester) async {
      const contact = ContactInfo(
        phone: '',
        email: '',
        website: '',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContactTile(contact: contact),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Contact details not available'), findsOneWidget);
    });
  });

  group('OpeningHoursTile Widget', () {
    testWidgets('shows "Opening hours not available" for empty hours', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OpeningHoursTile(openingHours: {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Opening hours not available'), findsOneWidget);
      // Empty state should be non-expandable - no expand icon
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);
    });

    testWidgets('shows collapsed status and expands to show days for non-empty hours', (WidgetTester tester) async {
      final openingHours = {
        'monday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'tuesday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'wednesday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'thursday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'friday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'saturday': const DayHours(open: '10:00', close: '16:00', closed: false),
        'sunday': const DayHours(open: '', close: '', closed: true),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpeningHoursTile(openingHours: openingHours),
          ),
        ),
      );
      await tester.pump();

      // Should show collapsed state with status (Open or Closed)
      expect(find.text('Opening hours'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      
      // Should show status (Open or Closed based on current time)
      // Check for the specific status words, avoiding "Opening hours" title
      final hasOpen = find.text('Open').evaluate().isNotEmpty;
      final hasClosed = find.text('Closed').evaluate().isNotEmpty;
      expect(hasOpen || hasClosed, isTrue, reason: 'Should show either Open or Closed status');

      // Days should NOT be visible initially
      expect(find.text('Monday'), findsNothing);
      expect(find.text('Tuesday'), findsNothing);

      // Tap the header to expand
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // Should now be expanded
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      
      // Days should now be visible
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('Wednesday'), findsOneWidget);
      expect(find.text('Thursday'), findsOneWidget);
      expect(find.text('Friday'), findsOneWidget);
      expect(find.text('Saturday'), findsOneWidget);
      expect(find.text('Sunday'), findsOneWidget);
    });

    testWidgets('shows "Closed" status when today is closed', (WidgetTester tester) async {
      // Current time is Wednesday, so set Wednesday as closed
      final now = DateTime.now();
      final todayWeekday = now.weekday; // 1=Monday, 2=Tuesday, ..., 7=Sunday
      final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final todayKey = dayNames[todayWeekday - 1];

      final openingHours = {
        'monday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'tuesday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'wednesday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'thursday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'friday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'saturday': const DayHours(open: '10:00', close: '16:00', closed: false),
        'sunday': const DayHours(open: '', close: '', closed: true),
      };

      // Set today as closed
      openingHours[todayKey] = const DayHours(open: '', close: '', closed: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpeningHoursTile(openingHours: openingHours),
          ),
        ),
      );
      await tester.pump();

      // Should show "Closed" status in collapsed state
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('shows "Open" status when today is open all day', (WidgetTester tester) async {
      // Current time is Wednesday, so set Wednesday as 24/7 open (00:00-23:59)
      final now = DateTime.now();
      final todayWeekday = now.weekday; // 1=Monday, 2=Tuesday, ..., 7=Sunday
      final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final todayKey = dayNames[todayWeekday - 1];

      final openingHours = {
        'monday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'tuesday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'wednesday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'thursday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'friday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'saturday': const DayHours(open: '10:00', close: '16:00', closed: false),
        'sunday': const DayHours(open: '', close: '', closed: true),
      };

      // Set today as 24/7 open
      openingHours[todayKey] = const DayHours(open: '00:00', close: '23:59', closed: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpeningHoursTile(openingHours: openingHours),
          ),
        ),
      );
      await tester.pump();

      // Should show "Open" status in collapsed state
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Closed'), findsNothing);
    });

    testWidgets('collapses when tapped again', (WidgetTester tester) async {
      final openingHours = {
        'monday': const DayHours(open: '09:00', close: '17:00', closed: false),
        'tuesday': const DayHours(open: '09:00', close: '17:00', closed: false),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpeningHoursTile(openingHours: openingHours),
          ),
        ),
      );
      await tester.pump();

      // Initially collapsed
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('Monday'), findsNothing);

      // Tap to expand
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // Should be expanded
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);

      // Tap again to collapse
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // Should be collapsed again
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('Monday'), findsNothing);
    });

    testWidgets('shows correct semantic labels for accessibility', (WidgetTester tester) async {
      final openingHours = {
        'monday': const DayHours(open: '09:00', close: '17:00', closed: false),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpeningHoursTile(openingHours: openingHours),
          ),
        ),
      );
      await tester.pump();

      // Find the semantic widget with specific accessibility label
      final semanticsWithLabel = find.byWidgetPredicate((widget) {
        return widget is Semantics && 
               widget.properties.label != null && 
               widget.properties.label!.contains('Opening hours') &&
               widget.properties.label!.contains('currently') &&
               widget.properties.label!.contains('tap to');
      });
      expect(semanticsWithLabel, findsOneWidget);

      // Verify the semantic properties
      final semantics = tester.widget<Semantics>(semanticsWithLabel);
      expect(semantics.properties.label, contains('Opening hours'));
      expect(semantics.properties.label, contains('currently'));
      expect(semantics.properties.label, contains('tap to'));
    });
  });

  group('PlaceActionButtons Widget', () {
    testWidgets('renders both action button labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceActionButtons(
              onGetRoute: () {},
              onReadReviews: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Get Accessible Route'), findsOneWidget);
      expect(find.text('Read Reviews'), findsOneWidget);
    });
  });
}