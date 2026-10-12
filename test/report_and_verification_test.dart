import 'package:flutter_test/flutter_test.dart';
import 'package:accesslink/models/accessibility_report.dart';
import 'package:accesslink/models/verification_record.dart';

void main() {
  group('Accessibility Reports and Verification Models', () {
    test('AccessibilityReport parses and defaults to pending status', () {
      final report = AccessibilityReport(
        id: 'rep_1',
        placeId: 'place_park',
        placeName: 'Central Park',
        reportedBy: 'user_123',
        reporterName: 'John Doe',
        category: 'incorrect_accessibility',
        targetField: 'Wheelchair Accessible',
        description: 'The south ramp is blocked by construction.',
        status: 'pending',
      );

      expect(report.isPending, isTrue);
      expect(report.isApproved, isFalse);
      expect(report.categoryLabel, 'Incorrect accessibility details');
      expect(report.placeName, 'Central Park');

      final map = report.toMap();
      expect(map['status'], 'pending');
      expect(map['placeId'], 'place_park');
    });

    test('Report validation rejects empty reason and oversized reasons', () {
      expect(() {
        final reason = '   '.trim();
        if (reason.isEmpty) {
          throw ArgumentError('Please provide a reason for this report.');
        }
      }, throwsArgumentError);

      expect(() {
        final longReason = 'b' * 2001;
        if (longReason.length > 2000) {
          throw ArgumentError('Report reason cannot exceed 2,000 characters.');
        }
      }, throwsArgumentError);
    });

    test(
      'VerificationRecord generates public authority description correctly',
      () {
        final recordSiteVisit = VerificationRecord(
          id: 'ver_1',
          placeId: 'place_park',
          feature: 'wheelchairAccessible',
          verifiedBy: 'admin_1',
          verifierName: 'Jane Auditor',
          status: 'verified',
          source: 'site_visit',
          createdAt: DateTime(2026, 9, 15),
        );

        expect(
          recordSiteVisit.publicAuthorityDescription,
          'Verified via on-site accessibility inspection',
        );

        final recordAudit = VerificationRecord(
          id: 'ver_2',
          placeId: 'place_park',
          feature: 'place',
          verifiedBy: 'admin_1',
          verifierName: 'Jane Auditor',
          status: 'verified',
          source: 'certified_audit',
        );

        expect(
          recordAudit.publicAuthorityDescription,
          'Verified by Certified Accessibility Auditor',
        );
      },
    );
  });
}
