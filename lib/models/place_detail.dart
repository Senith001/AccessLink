import 'package:cloud_firestore/cloud_firestore.dart';

class AccessibilityFeature {
  final bool available;
  final String notes;
  final bool verified;
  final DateTime? lastUpdated;

  const AccessibilityFeature({
    required this.available,
    required this.notes,
    required this.verified,
    this.lastUpdated,
  });

  factory AccessibilityFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const AccessibilityFeature(
        available: false,
        notes: '',
        verified: false,
        lastUpdated: null,
      );
    }

    return AccessibilityFeature(
      available: map['available'] as bool? ?? false,
      notes: map['notes'] as String? ?? '',
      verified: map['verified'] as bool? ?? false,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }
}

class DayHours {
  final String open;
  final String close;
  final bool closed;

  const DayHours({
    required this.open,
    required this.close,
    required this.closed,
  });

  factory DayHours.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const DayHours(open: '', close: '', closed: true);
    }

    return DayHours(
      open: map['open'] as String? ?? '',
      close: map['close'] as String? ?? '',
      closed: map['closed'] as bool? ?? false,
    );
  }

  String get display {
    if (closed || open.isEmpty || close.isEmpty) {
      return 'Closed';
    }
    return '$open – $close';
  }
}

class ContactInfo {
  final String phone;
  final String email;
  final String website;

  const ContactInfo({
    required this.phone,
    required this.email,
    required this.website,
  });

  factory ContactInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ContactInfo(phone: '', email: '', website: '');
    }

    return ContactInfo(
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      website: map['website'] as String? ?? '',
    );
  }

  bool get hasAny => phone.isNotEmpty || email.isNotEmpty || website.isNotEmpty;
}

class PlaceDetail {
  static const List<String> featureOrder = [
    'wheelchairAccessible',
    'accessibleToilet',
    'elevator',
    'accessibleParking',
    'tactilePaving',
    'audioSupport',
    'hearingSupport'
  ];

  static const Map<String, String> featureLabels = {
    'wheelchairAccessible': 'Wheelchair Accessible',
    'accessibleToilet': 'Accessible Toilet',
    'elevator': 'Elevator',
    'accessibleParking': 'Accessible Parking',
    'tactilePaving': 'Tactile Paving',
    'audioSupport': 'Audio Support',
    'hearingSupport': 'Hearing Support',
  };

  final String id;
  final String name;
  final String description;
  final String categoryName;
  final String address;
  final String district;
  final String city;
  final GeoPoint? location;
  final List<String> photos;
  final Map<String, DayHours> openingHours;
  final ContactInfo contact;
  final Map<String, AccessibilityFeature> features;
  final int accessibilityScore;
  final bool isVerified;
  final double ratingAverage;
  final int ratingCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PlaceDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryName,
    required this.address,
    required this.district,
    required this.city,
    this.location,
    required this.photos,
    required this.openingHours,
    required this.contact,
    required this.features,
    required this.accessibilityScore,
    required this.isVerified,
    required this.ratingAverage,
    required this.ratingCount,
    this.createdAt,
    this.updatedAt,
  });

  double? get latitude => location?.latitude;

  double? get longitude => location?.longitude;

  DateTime? get lastUpdated {
    DateTime? maxFeatureUpdated;
    
    for (final feature in features.values) {
      if (feature.lastUpdated != null) {
        if (maxFeatureUpdated == null || feature.lastUpdated!.isAfter(maxFeatureUpdated)) {
          maxFeatureUpdated = feature.lastUpdated;
        }
      }
    }
    
    return maxFeatureUpdated ?? updatedAt;
  }

  factory PlaceDetail.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('Document data is null');
    }

    // Build features map from accessibility data
    final accessibilityData = data['accessibility'] as Map<String, dynamic>? ?? {};
    final features = <String, AccessibilityFeature>{};
    
    for (final key in featureOrder) {
      features[key] = AccessibilityFeature.fromMap(
        accessibilityData[key] as Map<String, dynamic>?
      );
    }

    // Build opening hours map
    final openingHoursData = data['openingHours'] as Map<String, dynamic>? ?? {};
    final openingHours = <String, DayHours>{};
    
    for (final day in ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']) {
      openingHours[day] = DayHours.fromMap(
        openingHoursData[day] as Map<String, dynamic>?
      );
    }

    // Safe cast photos list
    final photosList = data['photos'] as List<dynamic>? ?? [];
    final photos = photosList.cast<String>();

    return PlaceDetail(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      district: data['district'] as String? ?? '',
      city: data['city'] as String? ?? '',
      location: data['location'] as GeoPoint?,
      photos: photos,
      openingHours: openingHours,
      contact: ContactInfo.fromMap(data['contact'] as Map<String, dynamic>?),
      features: features,
      accessibilityScore: data['accessibilityScore'] as int? ?? 0,
      isVerified: data['isVerified'] as bool? ?? false,
      ratingAverage: (data['ratingAverage'] as num?)?.toDouble() ?? 0.0,
      ratingCount: data['ratingCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}