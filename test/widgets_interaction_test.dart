import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:accesslink/widgets/place/rating_selector.dart';
import 'package:accesslink/widgets/place/verified_badge.dart';

void main() {
  group('Widget Interactions & Accessibility', () {
    testWidgets(
      'RatingSelector renders 5 stars and shows selected rating description',
      (WidgetTester tester) async {
        int selectedRating = 4;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return RatingSelector(
                    currentRating: selectedRating,
                    onRatingChanged: (val) {
                      setState(() => selectedRating = val);
                    },
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // Should display selected text: '4 - Good Accessibility'
        expect(find.text('4 - Good Accessibility'), findsOneWidget);

        // Verify tap on star 5 updates rating
        await tester.tap(find.bySemanticsLabel('Rate 5 out of 5 stars'));
        await tester.pump();

        expect(selectedRating, 5);
        expect(find.text('5 - Excellent Accessibility'), findsOneWidget);
      },
    );

    testWidgets('VerifiedBadge shows full label when showFullLabel is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const VerifiedBadge(isVerified: true, showFullLabel: true),
                const VerifiedBadge(isVerified: false, showFullLabel: true),
                VerifiedBadge(
                  isVerified: true,
                  showFullLabel: true,
                  authorityDescription: 'Municipal Inspector',
                  verifiedDate: DateTime(2026, 10, 1),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Verified accessibility information'), findsNWidgets(2));
      expect(find.text('Not yet verified'), findsOneWidget);
      expect(find.textContaining('Municipal Inspector'), findsOneWidget);
    });
  });
}
