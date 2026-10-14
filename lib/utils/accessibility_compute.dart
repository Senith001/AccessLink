/// Accessibility computation utilities for places.
/// 
/// This module provides pure Dart functions for computing accessibility scores,
/// flags, and verification status from accessibility feature data.
library;

/// The 7 standard accessibility feature keys used throughout the system.
const List<String> kAccessibilityFeatureKeys = [
  'wheelchairAccessible',
  'accessibleToilet', 
  'elevator',
  'accessibleParking',
  'tactilePaving',
  'audioSupport',
  'hearingSupport'
];

/// Helper function to compute accessibility score from accessibility features
int computeAccessibilityScore(Map<String, dynamic> accessibility) {
  final features = kAccessibilityFeatureKeys;
  
  int availableCount = 0;
  int presentCount = features.length; // All 7 features are always present
  
  for (final feature in features) {
    if (accessibility[feature]?['available'] == true) {
      availableCount++;
    }
  }
  
  if (presentCount == 0) return 0;
  return (availableCount / presentCount * 100).round();
}

/// Helper function to compute has* flags from accessibility features
Map<String, bool> computeAccessibilityFlags(Map<String, dynamic> accessibility) {
  return {
    'hasWheelchairAccess': accessibility['wheelchairAccessible']?['available'] ?? false,
    'hasAccessibleToilet': accessibility['accessibleToilet']?['available'] ?? false,
    'hasElevator': accessibility['elevator']?['available'] ?? false,
    'hasAccessibleParking': accessibility['accessibleParking']?['available'] ?? false,
    'hasTactilePaving': accessibility['tactilePaving']?['available'] ?? false,
    'hasAudioSupport': accessibility['audioSupport']?['available'] ?? false,
    'hasHearingSupport': accessibility['hearingSupport']?['available'] ?? false,
  };
}

/// Helper function to check if any accessibility feature is verified.
/// 
/// NOTE: This is a feature-level verification helper that returns true if ANY
/// individual accessibility feature has verified=true. This is NOT the source
/// for place-level verification badges (per Decision 2 in the admin panel spec).
bool isAccessibilityVerified(Map<String, dynamic> accessibility) {
  final features = kAccessibilityFeatureKeys;
  
  for (final feature in features) {
    if (accessibility[feature]?['verified'] == true) {
      return true;
    }
  }
  return false;
}