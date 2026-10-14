import 'package:flutter_test/flutter_test.dart';
import 'package:accesslink/services/report_moderation_service.dart';
void main() {
  test('rejects updates to protected place identity and ratings', () {
    expect(() => ReportModerationService.validatePlaceUpdate({'ratingAverage': 5}), throwsArgumentError);
    expect(() => ReportModerationService.validatePlaceUpdate({'id': 'other'}), throwsArgumentError);
  });
  test('validates accessibility score boundaries', () {
    ReportModerationService.validatePlaceUpdate({'accessibilityScore': 0});
    ReportModerationService.validatePlaceUpdate({'accessibilityScore': 100});
    expect(() => ReportModerationService.validatePlaceUpdate({'accessibilityScore': -1}), throwsArgumentError);
    expect(() => ReportModerationService.validatePlaceUpdate({'accessibilityScore': 101}), throwsArgumentError);
    expect(() => ReportModerationService.validatePlaceUpdate({'accessibilityScore': double.nan}), throwsArgumentError);
  });
  test('rejects malformed and unknown accessibility features', () {
    expect(() => ReportModerationService.validatePlaceUpdate({'accessibility': {'unknown': {}}}), throwsArgumentError);
    expect(() => ReportModerationService.validatePlaceUpdate({'accessibility': {'elevator': {'available': 'yes', 'verified': false, 'notes': ''}}}), throwsArgumentError);
  });
  test('accepts valid editable feature data', () {
    ReportModerationService.validatePlaceUpdate({'accessibility': {
      'elevator': {'available': true, 'verified': false, 'notes': 'Lift at main entrance'},
    }, 'hasElevator': true, 'isVerified': false});
  });
}
