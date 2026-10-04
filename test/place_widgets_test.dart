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

      expect(find.textContaining('unverified'), findsOneWidget);
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