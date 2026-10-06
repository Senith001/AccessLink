import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of an accessibility feature.
/// Distinguishes Yes, No, and Unknown. Missing data is NEVER treated as No.
enum AccessibilityStatus {
  yes,
  no,
  unknown;

  String get label {
    switch (this) {
      case AccessibilityStatus.yes:
        return 'Yes';
      case AccessibilityStatus.no:
        return 'No';
      case AccessibilityStatus.unknown:
        return 'Unknown';
    }
  }

  static AccessibilityStatus fromValue(dynamic val) {
    if (val == null) return AccessibilityStatus.unknown;
    final s = val.toString().trim().toLowerCase();
    if (s == 'yes' || s == 'true' || s == 'designated' || s == 'limited') {
      return AccessibilityStatus.yes;
    }
    if (s == 'no' || s == 'false') {
      return AccessibilityStatus.no;
    }
    return AccessibilityStatus.unknown;
  }
}

class Place {
  final String id;
  final String name;
  final String address;
  final String categoryName;
  final GeoPoint location;
  final bool isVerified;

  // Specific accessibility features
  final AccessibilityStatus wheelchair;
  final AccessibilityStatus ramp;
  final AccessibilityStatus elevator;
  final AccessibilityStatus accessibleToilet;
  final AccessibilityStatus accessibleParking;
  final AccessibilityStatus tactilePaving;
  final AccessibilityStatus hearingSupport;

  // Admin-approved correction if any
  final String? correctedAccessibilityInfo;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.categoryName,
    required this.location,
    required this.isVerified,
    this.wheelchair = AccessibilityStatus.unknown,
    this.ramp = AccessibilityStatus.unknown,
    this.elevator = AccessibilityStatus.unknown,
    this.accessibleToilet = AccessibilityStatus.unknown,
    this.accessibleParking = AccessibilityStatus.unknown,
    this.tactilePaving = AccessibilityStatus.unknown,
    this.hearingSupport = AccessibilityStatus.unknown,
    this.correctedAccessibilityInfo,
  });

  factory Place.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return Place(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      categoryName: data['categoryName'] ?? '',
      location: (data['location'] is GeoPoint)
          ? data['location'] as GeoPoint
          : const GeoPoint(0, 0),
      isVerified: data['isVerified'] == true,
      wheelchair: AccessibilityStatus.fromValue(data['wheelchair']),
      ramp: AccessibilityStatus.fromValue(data['ramp']),
      elevator: AccessibilityStatus.fromValue(data['elevator']),
      accessibleToilet: AccessibilityStatus.fromValue(data['accessibleToilet']),
      accessibleParking: AccessibilityStatus.fromValue(data['accessibleParking']),
      tactilePaving: AccessibilityStatus.fromValue(data['tactilePaving']),
      hearingSupport: AccessibilityStatus.fromValue(data['hearingSupport']),
      correctedAccessibilityInfo: data['correctedAccessibilityInfo'] as String?,
    );
  }

  Place copyWith({
    String? id,
    String? name,
    String? address,
    String? categoryName,
    GeoPoint location,
    bool? isVerified,
    AccessibilityStatus? wheelchair,
    AccessibilityStatus? ramp,
    AccessibilityStatus? elevator,
    AccessibilityStatus? accessibleToilet,
    AccessibilityStatus? accessibleParking,
    AccessibilityStatus? tactilePaving,
    AccessibilityStatus? hearingSupport,
    String? correctedAccessibilityInfo,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      categoryName: categoryName ?? this.categoryName,
      location: location ?? this.location,
      isVerified: isVerified ?? this.isVerified,
      wheelchair: wheelchair ?? this.wheelchair,
      ramp: ramp ?? this.ramp,
      elevator: elevator ?? this.elevator,
      accessibleToilet: accessibleToilet ?? this.accessibleToilet,
      accessibleParking: accessibleParking ?? this.accessibleParking,
      tactilePaving: tactilePaving ?? this.tactilePaving,
      hearingSupport: hearingSupport ?? this.hearingSupport,
      correctedAccessibilityInfo:
          correctedAccessibilityInfo ?? this.correctedAccessibilityInfo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'categoryName': categoryName,
      'location': location,
      'isVerified': isVerified,
      'wheelchair': wheelchair.name,
      'ramp': ramp.name,
      'elevator': elevator.name,
      'accessibleToilet': accessibleToilet.name,
      'accessibleParking': accessibleParking.name,
      'tactilePaving': tactilePaving.name,
      'hearingSupport': hearingSupport.name,
      if (correctedAccessibilityInfo != null)
        'correctedAccessibilityInfo': correctedAccessibilityInfo,
    };
  }

  double get latitude => location.latitude;

  double get longitude => location.longitude;
}