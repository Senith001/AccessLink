import 'package:flutter_test/flutter_test.dart';

import 'package:accesslink/models/accessibility_report.dart';

void main() {
  group('AccessibilityReport model', () {
    test('toFirestore contains all required fields', () {
      final now = DateTime(2026, 9, 29, 12, 0);
      final report = AccessibilityReport(
        id: 'report-1',
        placeId: 'place-1',
        placeName: 'Test Place',
        reporterUid: 'user-1',
        reason: 'Ramp is blocked',
        status: ReportStatus.pending,
        createdAt: now,
      );
      final map = report.toFirestore();
      expect(map['placeId'], 'place-1');
      expect(map['placeName'], 'Test Place');
      expect(map['reporterUid'], 'user-1');
      expect(map['reason'], 'Ramp is blocked');
      expect(map['status'], 'pending');
      expect(map.containsKey('createdAt'), isTrue);
      // No reviewer fields when unreviewed.
      expect(map.containsKey('reviewerUid'), isFalse);
      expect(map.containsKey('reviewedAt'), isFalse);
    });

    test('toFirestore includes reviewer fields when present', () {
      final now = DateTime(2026, 9, 29, 12, 0);
      final report = AccessibilityReport(
        id: 'report-2',
        placeId: 'place-1',
        placeName: 'Test Place',
        reporterUid: 'user-1',
        reason: 'Missing ramp',
        status: ReportStatus.approved,
        createdAt: now,
        reviewerUid: 'admin-1',
        reviewedAt: now,
        correctedInfo: 'Ramp available at side entrance',
      );
      final map = report.toFirestore();
      expect(map['status'], 'approved');
      expect(map['reviewerUid'], 'admin-1');
      expect(map.containsKey('reviewedAt'), isTrue);
      expect(map['correctedInfo'], 'Ramp available at side entrance');
    });

    test('ReportStatus parsing handles all values', () {
      // Verify round-trip through name.
      for (final status in ReportStatus.values) {
        final report = AccessibilityReport(
          id: 'r',
          placeId: 'p',
          placeName: 'n',
          reporterUid: 'u',
          reason: 'reason',
          status: status,
          createdAt: DateTime.now(),
        );
        final map = report.toFirestore();
        expect(map['status'], status.name);
      }
    });
  });
}
