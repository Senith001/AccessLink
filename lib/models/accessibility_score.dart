import 'search_place.dart';

class AccessibilityScore {
  const AccessibilityScore({
    required this.availableFeatures,
    this.totalFeatures = _totalKnownFeatures,
  });

  factory AccessibilityScore.fromPlace(SearchPlace place) {
    return AccessibilityScore(availableFeatures: place.accessibilityFeatures);
  }

  final Set<String> availableFeatures;
  final int totalFeatures;

  bool get canShow => availableFeatures.isNotEmpty && totalFeatures > 0;

  int get percent {
    if (!canShow) return 0;
    return ((availableFeatures.length / totalFeatures) * 100).round().clamp(
      0,
      100,
    );
  }

  String get label => 'Score $percent%';
}

const _totalKnownFeatures = 7;
