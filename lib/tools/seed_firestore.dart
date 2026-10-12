import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../core/database/firestore_collections.dart';
import '../firebase_options.dart';

/// Helper function to compute accessibility score from accessibility features
int computeAccessibilityScore(Map<String, dynamic> accessibility) {
  final features = [
    'wheelchairAccessible',
    'accessibleToilet', 
    'elevator',
    'accessibleParking',
    'tactilePaving',
    'audioSupport',
    'hearingSupport'
  ];
  
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

/// Helper function to check if any accessibility feature is verified
bool isAccessibilityVerified(Map<String, dynamic> accessibility) {
  final features = [
    'wheelchairAccessible',
    'accessibleToilet', 
    'elevator',
    'accessibleParking',
    'tactilePaving',
    'audioSupport',
    'hearingSupport'
  ];
  
  for (final feature in features) {
    if (accessibility[feature]?['verified'] == true) {
      return true;
    }
  }
  return false;
}

Future<void> main() async {
  // Initialize Flutter bindings and Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final firestore = FirebaseFirestore.instance;
  
  // Print banner
  print('=' * 60);
  print('🌱 SEEDING FIRESTORE DATABASE');
  print('📦 Project: access-link-005');
  print('⚠️  Mode: ADDITIVE (creates/merges, deletes nothing)');
  print('🔄 Re-running is safe (uses fixed document IDs)');
  print('=' * 60);
  print('');
  
  // Track seeding results
  final results = <String, int>{};
  final denied = <String, List<String>>{};
  
  // 1. Seed Categories
  print('📁 Seeding categories...');
  final categories = [
    {
      'id': 'cat_park',
      'name': 'Park',
      'description': 'Public parks and recreational areas',
      'icon': 'park',
      'order': 1,
    },
    {
      'id': 'cat_library', 
      'name': 'Library',
      'description': 'Public libraries and reading spaces',
      'icon': 'library_books',
      'order': 2,
    },
    {
      'id': 'cat_restaurant',
      'name': 'Restaurant', 
      'description': 'Restaurants and dining establishments',
      'icon': 'restaurant',
      'order': 3,
    },
    {
      'id': 'cat_hospital',
      'name': 'Hospital',
      'description': 'Hospitals and healthcare facilities',
      'icon': 'local_hospital',
      'order': 4,
    },
    // New categories for Colombo accessibility seeding
    {
      'id': 'cat_hotel',
      'name': 'Hotel',
      'description': 'Hotels and accommodation',
      'icon': 'hotel',
      'order': 5,
    },
    {
      'id': 'cat_supermarket',
      'name': 'Supermarket',
      'description': 'Supermarkets and grocery stores',
      'icon': 'local_grocery_store',
      'order': 6,
    },
    {
      'id': 'cat_washroom',
      'name': 'Washroom',
      'description': 'Public washrooms and toilets',
      'icon': 'wc',
      'order': 7,
    },
  ];
  
  int categoryCount = 0;
  final categoryDenied = <String>[];
  
  for (final cat in categories) {
    try {
      await firestore
          .collection(FirestoreCollections.categories)
          .doc(cat['id'] as String)
          .set({
        'name': cat['name'],
        'description': cat['description'],
        'icon': cat['icon'],
        'order': cat['order'],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      categoryCount++;
      print('  ✅ Created category: ${cat['name']}');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        categoryDenied.add(cat['id'] as String);
        print('  ❌ Permission denied for category: ${cat['name']}');
      } else {
        print('  ⚠️  Error creating category ${cat['name']}: ${e.message}');
      }
    }
  }
  results[FirestoreCollections.categories] = categoryCount;
  if (categoryDenied.isNotEmpty) {
    denied[FirestoreCollections.categories] = categoryDenied;
  }
  
  // 2. Seed Places
  print('\n🏢 Seeding places...');
  final now = Timestamp.now();
  
  final places = [
    {
      'id': 'place_central_park',
      'name': 'Central Park',
      'description': 'A large public park in the heart of the city with walking trails, playgrounds, and green spaces.',
      'categoryId': 'cat_park',
      'categoryName': 'Park',
      'address': '123 Park Avenue',
      'district': 'Downtown',
      'city': 'Metro City',
      'location': const GeoPoint(40.7829, -73.9654), // Central Park NYC coords
      'geohash': '9q8yyk8yugs8',
      'contact': {
        'phone': '+1-555-0123',
        'email': 'info@centralpark.gov',
        'website': 'https://centralpark.gov'
      },
      'openingHours': {
        'monday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'tuesday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'wednesday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'thursday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'friday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'saturday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'sunday': {'open': '06:00', 'close': '22:00', 'closed': false},
      },
      // 5/7 features available = 71% score
      'accessibility': {
        'wheelchairAccessible': {'available': true, 'notes': 'Paved paths throughout', 'verified': true, 'lastUpdated': now},
        'accessibleToilet': {'available': true, 'notes': 'Available in visitor center', 'verified': false, 'lastUpdated': now},
        'elevator': {'available': false, 'notes': 'No multi-story buildings', 'verified': false, 'lastUpdated': now},
        'accessibleParking': {'available': true, 'notes': 'Designated spaces at main entrance', 'verified': false, 'lastUpdated': now},
        'tactilePaving': {'available': false, 'notes': 'Not available on trails', 'verified': false, 'lastUpdated': now},
        'audioSupport': {'available': true, 'notes': 'Audio tour available', 'verified': false, 'lastUpdated': now},
        'hearingSupport': {'available': true, 'notes': 'ASL interpreter on request', 'verified': false, 'lastUpdated': now},
      }
    },
    {
      'id': 'place_city_library',
      'name': 'City Central Library',
      'description': 'Main public library with extensive collection, reading rooms, and computer access.',
      'categoryId': 'cat_library',
      'categoryName': 'Library',
      'address': '456 Library Street',
      'district': 'Cultural District',
      'city': 'Metro City',
      'location': const GeoPoint(40.7505, -73.9934),
      'geohash': '9q8yyj2h4b9s',
      'contact': {
        'phone': '+1-555-0456',
        'email': 'info@citylibrary.org',
        'website': 'https://citylibrary.org'
      },
      'openingHours': {
        'monday': {'open': '09:00', 'close': '20:00', 'closed': false},
        'tuesday': {'open': '09:00', 'close': '20:00', 'closed': false},
        'wednesday': {'open': '09:00', 'close': '20:00', 'closed': false},
        'thursday': {'open': '09:00', 'close': '20:00', 'closed': false},
        'friday': {'open': '09:00', 'close': '18:00', 'closed': false},
        'saturday': {'open': '10:00', 'close': '17:00', 'closed': false},
        'sunday': {'open': '12:00', 'close': '17:00', 'closed': false},
      },
      // 7/7 features available = 100% score
      'accessibility': {
        'wheelchairAccessible': {'available': true, 'notes': 'Ramps and wide doorways', 'verified': false, 'lastUpdated': now},
        'accessibleToilet': {'available': true, 'notes': 'On each floor', 'verified': false, 'lastUpdated': now},
        'elevator': {'available': true, 'notes': 'Access to all 3 floors', 'verified': false, 'lastUpdated': now},
        'accessibleParking': {'available': true, 'notes': '4 designated spaces in front', 'verified': false, 'lastUpdated': now},
        'tactilePaving': {'available': true, 'notes': 'At entrance and key pathways', 'verified': false, 'lastUpdated': now},
        'audioSupport': {'available': true, 'notes': 'Assistive listening devices available', 'verified': false, 'lastUpdated': now},
        'hearingSupport': {'available': true, 'notes': 'Hearing loop system installed', 'verified': false, 'lastUpdated': now},
      }
    }
  ];
  
  int placeCount = 0;
  final placeDenied = <String>[];
  
  for (final place in places) {
    try {
      final accessibility = place['accessibility'] as Map<String, dynamic>;
      final accessibilityScore = computeAccessibilityScore(accessibility);
      final accessibilityFlags = computeAccessibilityFlags(accessibility);
      final isVerified = isAccessibilityVerified(accessibility);
      final name = place['name'] as String;
      
      final placeData = {
        'name': name,
        'nameLower': name.trim().toLowerCase(),
        'description': place['description'],
        'categoryId': place['categoryId'],
        'categoryName': place['categoryName'],
        'address': place['address'],
        'district': place['district'],
        'city': place['city'],
        'location': place['location'],
        'geohash': place['geohash'],
        'photos': <String>[],
        'openingHours': place['openingHours'],
        'contact': place['contact'],
        'accessibility': accessibility,
        ...accessibilityFlags,
        'accessibilityScore': accessibilityScore,
        'isVerified': isVerified,
        'ratingAverage': 0.0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await firestore
          .collection(FirestoreCollections.places)
          .doc(place['id'] as String)
          .set(placeData, SetOptions(merge: true));
      
      placeCount++;
      print('  ✅ Created place: ${place['name']} (accessibility score: $accessibilityScore%)');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        placeDenied.add(place['id'] as String);
        print('  ❌ Permission denied for place: ${place['name']}');
      } else {
        print('  ⚠️  Error creating place ${place['name']}: ${e.message}');
      }
    }
  }
  results[FirestoreCollections.places] = placeCount;
  if (placeDenied.isNotEmpty) {
    denied[FirestoreCollections.places] = placeDenied;
  }
  
  // Colombo Accessibility Places Seeding (Additive)
  print('\n🏢 Seeding Colombo accessibility places...');
  
  final colomboPlaces = [
    {
      'id': 'place_colombo_city_hospital',
      'name': 'Colombo City Hospital',
      'description': 'General hospital serving central Colombo.',
      'categoryId': 'cat_hospital',
      'categoryName': 'Hospital',
      'address': 'Galle Road, Colombo',
      'district': 'Colombo',
      'city': 'Colombo',
      'location': const GeoPoint(6.9271, 79.8612),
      'geohash': '',
      'contact': {
        'phone': '',
        'email': '',
        'website': ''
      },
      'openingHours': {
        'monday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'tuesday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'wednesday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'thursday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'friday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'saturday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'sunday': {'open': '00:00', 'close': '23:59', 'closed': false},
      },
      'accessibility': {
        'wheelchairAccessible': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleToilet': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'elevator': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleParking': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'tactilePaving': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'audioSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'hearingSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
      }
    },
    {
      'id': 'place_cinnamon_grand',
      'name': 'Cinnamon Grand',
      'description': 'City hotel in Colombo 03.',
      'categoryId': 'cat_hotel',
      'categoryName': 'Hotel',
      'address': 'Colombo 03',
      'district': 'Colombo 03',
      'city': 'Colombo',
      'location': const GeoPoint(6.9271, 79.8487),
      'geohash': '',
      'contact': {
        'phone': '',
        'email': '',
        'website': ''
      },
      'openingHours': {
        'monday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'tuesday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'wednesday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'thursday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'friday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'saturday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'sunday': {'open': '00:00', 'close': '23:59', 'closed': false},
      },
      'accessibility': {
        'wheelchairAccessible': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleToilet': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'elevator': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleParking': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'tactilePaving': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'audioSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'hearingSupport': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
      }
    },
    {
      'id': 'place_laksala',
      'name': 'Laksala',
      'description': 'Retail outlet in Kollupitiya.',
      'categoryId': 'cat_supermarket',
      'categoryName': 'Supermarket',
      'address': 'Kollupitiya',
      'district': 'Kollupitiya',
      'city': 'Colombo',
      'location': const GeoPoint(6.9054, 79.8533),
      'geohash': '',
      'contact': {
        'phone': '',
        'email': '',
        'website': ''
      },
      'openingHours': {
        'monday': {'open': '09:00', 'close': '21:00', 'closed': false},
        'tuesday': {'open': '09:00', 'close': '21:00', 'closed': false},
        'wednesday': {'open': '09:00', 'close': '21:00', 'closed': false},
        'thursday': {'open': '09:00', 'close': '21:00', 'closed': false},
        'friday': {'open': '09:00', 'close': '21:00', 'closed': false},
        'saturday': {'open': '09:00', 'close': '21:00', 'closed': false},
        'sunday': {'open': '10:00', 'close': '20:00', 'closed': false},
      },
      'accessibility': {
        'wheelchairAccessible': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleToilet': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'elevator': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleParking': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'tactilePaving': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'audioSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'hearingSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
      }
    },
    {
      'id': 'place_avenue_hospital',
      'name': 'Avenue Hospital',
      'description': 'Private hospital on Ward Place.',
      'categoryId': 'cat_hospital',
      'categoryName': 'Hospital',
      'address': 'Ward Place',
      'district': 'Colombo 07',
      'city': 'Colombo',
      'location': const GeoPoint(6.9034, 79.8746),
      'geohash': '',
      'contact': {
        'phone': '',
        'email': '',
        'website': ''
      },
      'openingHours': {
        'monday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'tuesday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'wednesday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'thursday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'friday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'saturday': {'open': '00:00', 'close': '23:59', 'closed': false},
        'sunday': {'open': '00:00', 'close': '23:59', 'closed': false},
      },
      'accessibility': {
        'wheelchairAccessible': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleToilet': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'elevator': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleParking': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'tactilePaving': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'audioSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'hearingSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
      }
    },
    {
      'id': 'place_colombo_public_toilet',
      'name': 'Colombo Public Toilet',
      'description': 'Public washroom in Fort.',
      'categoryId': 'cat_washroom',
      'categoryName': 'Washroom',
      'address': 'Fort',
      'district': 'Fort',
      'city': 'Colombo',
      'location': const GeoPoint(6.9355, 79.8437),
      'geohash': '',
      'contact': {
        'phone': '',
        'email': '',
        'website': ''
      },
      'openingHours': {
        'monday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'tuesday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'wednesday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'thursday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'friday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'saturday': {'open': '06:00', 'close': '22:00', 'closed': false},
        'sunday': {'open': '06:00', 'close': '22:00', 'closed': false},
      },
      'accessibility': {
        'wheelchairAccessible': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleToilet': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'elevator': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleParking': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'tactilePaving': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'audioSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'hearingSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
      }
    },
    {
      'id': 'place_kingsbury_restaurant',
      'name': 'Kingsbury Restaurant',
      'description': 'Restaurant on Marine Drive.',
      'categoryId': 'cat_restaurant',
      'categoryName': 'Restaurant',
      'address': 'Marine Drive',
      'district': 'Colombo 01',
      'city': 'Colombo',
      'location': const GeoPoint(6.9255, 79.8407),
      'geohash': '',
      'contact': {
        'phone': '',
        'email': '',
        'website': ''
      },
      'openingHours': {
        'monday': {'open': '12:00', 'close': '23:00', 'closed': false},
        'tuesday': {'open': '12:00', 'close': '23:00', 'closed': false},
        'wednesday': {'open': '12:00', 'close': '23:00', 'closed': false},
        'thursday': {'open': '12:00', 'close': '23:00', 'closed': false},
        'friday': {'open': '12:00', 'close': '23:00', 'closed': false},
        'saturday': {'open': '12:00', 'close': '23:00', 'closed': false},
        'sunday': {'open': '12:00', 'close': '23:00', 'closed': false},
      },
      'accessibility': {
        'wheelchairAccessible': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleToilet': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'elevator': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleParking': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'tactilePaving': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'audioSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'hearingSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
      }
    },
    {
      'id': 'place_cargills_food_city',
      'name': 'Cargills Food City',
      'description': 'Supermarket in Borella.',
      'categoryId': 'cat_supermarket',
      'categoryName': 'Supermarket',
      'address': 'Borella',
      'district': 'Borella',
      'city': 'Colombo',
      'location': const GeoPoint(6.9138, 79.8789),
      'geohash': '',
      'contact': {
        'phone': '',
        'email': '',
        'website': ''
      },
      'openingHours': {
        'monday': {'open': '08:00', 'close': '22:00', 'closed': false},
        'tuesday': {'open': '08:00', 'close': '22:00', 'closed': false},
        'wednesday': {'open': '08:00', 'close': '22:00', 'closed': false},
        'thursday': {'open': '08:00', 'close': '22:00', 'closed': false},
        'friday': {'open': '08:00', 'close': '22:00', 'closed': false},
        'saturday': {'open': '08:00', 'close': '22:00', 'closed': false},
        'sunday': {'open': '09:00', 'close': '21:00', 'closed': false},
      },
      'accessibility': {
        'wheelchairAccessible': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleToilet': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'elevator': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleParking': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'tactilePaving': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'audioSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'hearingSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
      }
    },
    {
      'id': 'place_bocca_restaurant',
      'name': 'Bocca Restaurant',
      'description': 'Restaurant in Colombo 07.',
      'categoryId': 'cat_restaurant',
      'categoryName': 'Restaurant',
      'address': 'Colombo 07',
      'district': 'Colombo 07',
      'city': 'Colombo',
      'location': const GeoPoint(6.9068, 79.8544),
      'geohash': '',
      'contact': {
        'phone': '',
        'email': '',
        'website': ''
      },
      'openingHours': {
        'monday': {'open': '18:00', 'close': '23:00', 'closed': false},
        'tuesday': {'open': '18:00', 'close': '23:00', 'closed': false},
        'wednesday': {'open': '18:00', 'close': '23:00', 'closed': false},
        'thursday': {'open': '18:00', 'close': '23:00', 'closed': false},
        'friday': {'open': '18:00', 'close': '23:00', 'closed': false},
        'saturday': {'open': '18:00', 'close': '23:00', 'closed': false},
        'sunday': {'open': '18:00', 'close': '23:00', 'closed': false},
      },
      'accessibility': {
        'wheelchairAccessible': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleToilet': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'elevator': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'accessibleParking': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'tactilePaving': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'audioSupport': {'available': false, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
        'hearingSupport': {'available': true, 'notes': 'Sample data – not yet verified.', 'verified': false, 'lastUpdated': now},
      }
    },
  ];
  
  int colomboPlaceCount = 0;
  final colomboPlaceDenied = <String>[];
  
  for (final place in colomboPlaces) {
    try {
      final accessibility = place['accessibility'] as Map<String, dynamic>;
      final accessibilityScore = computeAccessibilityScore(accessibility);
      final accessibilityFlags = computeAccessibilityFlags(accessibility);
      final isVerified = isAccessibilityVerified(accessibility);
      final name = place['name'] as String;
      
      final placeData = {
        'name': name,
        'nameLower': name.trim().toLowerCase(),
        'description': place['description'],
        'categoryId': place['categoryId'],
        'categoryName': place['categoryName'],
        'address': place['address'],
        'district': place['district'],
        'city': place['city'],
        'location': place['location'],
        'geohash': place['geohash'],
        'photos': <String>[],
        'openingHours': place['openingHours'],
        'contact': place['contact'],
        'accessibility': accessibility,
        ...accessibilityFlags,
        'accessibilityScore': accessibilityScore,
        'isVerified': isVerified,
        'ratingAverage': 0.0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await firestore
          .collection(FirestoreCollections.places)
          .doc(place['id'] as String)
          .set(placeData, SetOptions(merge: true));
      
      colomboPlaceCount++;
      print('  ✅ Created Colombo place: ${place['name']} (accessibility score: $accessibilityScore%)');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        colomboPlaceDenied.add(place['id'] as String);
        print('  ❌ Permission denied for Colombo place: ${place['name']}');
      } else {
        print('  ⚠️  Error creating Colombo place ${place['name']}: ${e.message}');
      }
    }
  }
  
  // Update results with Colombo places count (additive to existing places count)
  results[FirestoreCollections.places] = placeCount + colomboPlaceCount;
  if (placeDenied.isNotEmpty || colomboPlaceDenied.isNotEmpty) {
    denied[FirestoreCollections.places] = [...placeDenied, ...colomboPlaceDenied];
  }
  
  // 3. Seed Reviews
  print('\n⭐ Seeding reviews...');
  int reviewCount = 0;
  final reviewDenied = <String>[];
  
  const reviewRating = 4;
  try {
    await firestore
        .collection(FirestoreCollections.reviews)
        .doc('review_seed_1')
        .set({
      'placeId': 'place_central_park',
      'userId': 'seed_user_001',
      'userName': 'John Doe',
      'rating': reviewRating,
      'text': 'Great park with good accessibility features. The paved paths make it easy to navigate with a wheelchair.',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    reviewCount++;
    print('  ✅ Created review for Central Park');
    
    // Update the place's rating to reflect this review
    try {
      await firestore
          .collection(FirestoreCollections.places)
          .doc('place_central_park')
          .update({
        'ratingAverage': reviewRating.toDouble(),
        'ratingCount': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('  ✅ Updated Central Park rating (${reviewRating.toDouble()}/5.0, 1 review)');
    } on FirebaseException catch (e) {
      print('  ⚠️  Could not update place rating: ${e.message}');
    }
    
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      reviewDenied.add('review_seed_1');
      print('  ❌ Permission denied for review');
    } else {
      print('  ⚠️  Error creating review: ${e.message}');
    }
  }
  
  // Add second review by caregiver
  const caregiverReviewRating = 5;
  try {
    await firestore
        .collection(FirestoreCollections.reviews)
        .doc('review_seed_2')
        .set({
      'placeId': 'place_city_library',
      'userId': 'seed_user_002',
      'userName': 'Mary Carer',
      'rating': caregiverReviewRating,
      'text': 'Excellent accessibility features at this library. I brought my parent here and they were able to access all floors easily with the elevator and wide pathways. The staff was very helpful too.',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    reviewCount++;
    print('  ✅ Created review for City Library');
    
    // Update the library's rating to reflect this review
    try {
      await firestore
          .collection(FirestoreCollections.places)
          .doc('place_city_library')
          .update({
        'ratingAverage': caregiverReviewRating.toDouble(),
        'ratingCount': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('  ✅ Updated City Library rating (${caregiverReviewRating.toDouble()}/5.0, 1 review)');
    } on FirebaseException catch (e) {
      print('  ⚠️  Could not update library rating: ${e.message}');
    }
    
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      reviewDenied.add('review_seed_2');
      print('  ❌ Permission denied for caregiver review');
    } else {
      print('  ⚠️  Error creating caregiver review: ${e.message}');
    }
  }
  
  results[FirestoreCollections.reviews] = reviewCount;
  if (reviewDenied.isNotEmpty) {
    denied[FirestoreCollections.reviews] = reviewDenied;
  }
  
  // 4. Seed Reports
  print('\n📋 Seeding reports...');
  int reportCount = 0;
  final reportDenied = <String>[];
  
  try {
    await firestore
        .collection(FirestoreCollections.reports)
        .doc('report_seed_1')
        .set({
      'placeId': 'place_central_park',
      'reportedBy': 'seed_user_001',
      'reporterName': 'John Doe',
      'targetField': 'accessibility.accessibleToilet.available',
      'currentValue': true,
      'suggestedValue': false,
      'description': 'The accessible toilet in the visitor center has been out of order for maintenance since last week.',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    reportCount++;
    print('  ✅ Created accessibility report for Central Park');
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      reportDenied.add('report_seed_1');
      print('  ❌ Permission denied for report');
    } else {
      print('  ⚠️  Error creating report: ${e.message}');
    }
  }
  results[FirestoreCollections.reports] = reportCount;
  if (reportDenied.isNotEmpty) {
    denied[FirestoreCollections.reports] = reportDenied;
  }
  
  // 5. Seed Verification Records
  print('\n✅ Seeding verification records...');
  int verificationCount = 0;
  final verificationDenied = <String>[];
  
  try {
    await firestore
        .collection(FirestoreCollections.verificationRecords)
        .doc('ver_seed_1')
        .set({
      'placeId': 'place_central_park',
      'feature': 'wheelchairAccessible',
      'verifiedBy': 'seed_admin_001',
      'verifierName': 'Admin User',
      'status': 'verified',
      'source': 'site_visit',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    verificationCount++;
    print('  ✅ Created verification record for Central Park wheelchair access');
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      verificationDenied.add('ver_seed_1');
      print('  ❌ Permission denied for verification record');
    } else {
      print('  ⚠️  Error creating verification record: ${e.message}');
    }
  }
  results[FirestoreCollections.verificationRecords] = verificationCount;
  if (verificationDenied.isNotEmpty) {
    denied[FirestoreCollections.verificationRecords] = verificationDenied;
  }
  
  // 6. Seed Users
  print('\n👥 Seeding users...');
  int userCount = 0;
  final userDenied = <String>[];
  
  final users = [
    {
      'id': 'seed_user_001',
      'name': 'John Doe',
      'email': 'john.doe@example.com',
      'userType': 'personWithDisability',
      'role': 'user',
      'accessibilityNeeds': ['wheelchair'],
      'textScale': 1.0,
      'highContrast': false,
    },
    {
      'id': 'seed_user_002',
      'name': 'Mary Carer',
      'email': 'mary.carer@example.com',
      'userType': 'caregiver',
      'role': 'user',
      'accessibilityNeeds': <String>[],
      'caregiverFor': ['parent with mobility impairment'],
      'textScale': 1.0,
      'highContrast': false,
    },
    {
      'id': 'seed_user_003',
      'name': 'Alex Helper',
      'email': 'alex.helper@example.com',
      'userType': 'contributor',
      'role': 'user',
      'accessibilityNeeds': <String>[],
      'textScale': 1.0,
      'highContrast': false,
    },
  ];
  
  for (final user in users) {
    try {
      final userData = <String, dynamic>{
        'name': user['name'],
        'email': user['email'],
        'userType': user['userType'],
        'role': user['role'],
        'accessibilityNeeds': user['accessibilityNeeds'],
        'textScale': user['textScale'],
        'highContrast': user['highContrast'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Only add caregiverFor for caregiver type
      if (user['userType'] == 'caregiver') {
        userData['caregiverFor'] = user['caregiverFor'];
      }
      
      await firestore
          .collection(FirestoreCollections.users)
          .doc(user['id'] as String)
          .set(userData, SetOptions(merge: true));
      
      userCount++;
      print('  ✅ Created user: ${user['name']} (${user['userType']})');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        userDenied.add(user['id'] as String);
        print('  ❌ Permission denied for user: ${user['name']}');
      } else {
        print('  ⚠️  Error creating user ${user['name']}: ${e.message}');
      }
    }
  }
  
  // Create favorites subcollection for seed_user_001 (person with disability)
  try {
    await firestore
        .collection(FirestoreCollections.users)
        .doc('seed_user_001')
        .collection('favorites')
        .doc('place_central_park')
        .set({
      'placeId': 'place_central_park',
      'placeName': 'Central Park',
      'dateAdded': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    print('  ✅ Added Central Park to John Doe favorites');
  } on FirebaseException catch (e) {
    print('  ⚠️  Could not create user favorite: ${e.message}');
  }
  
  results[FirestoreCollections.users] = userCount;
  if (userDenied.isNotEmpty) {
    denied[FirestoreCollections.users] = userDenied;
  }
  
  // Print final summary
  print('\n${'=' * 60}');
  print('📊 SEEDING SUMMARY');
  print('=' * 60);
  
  var totalCreated = 0;
  var totalDenied = 0;
  
  for (final entry in results.entries) {
    final collection = entry.key;
    final count = entry.value;
    final deniedList = denied[collection] ?? [];
    
    print('📁 $collection: $count created${deniedList.isNotEmpty ? ', ${deniedList.length} denied' : ''}');
    totalCreated += count;
    totalDenied += deniedList.length;
  }
  
  print('\n📈 Total: $totalCreated documents created');
  
  if (totalDenied > 0) {
    print('⚠️  $totalDenied documents were denied due to Firestore security rules');
    print('');
    print('🔐 PERMISSION DENIED HELP:');
    print('   The Firestore security rules blocked some writes.');
    print('   To fix this, either:');
    print('   1. Run this script while authenticated as a user with write permissions');
    print('   2. Temporarily update your Firestore rules to allow writes');
    print('   3. Use Firebase Admin SDK with service account credentials');
    print('');
    print('   Example open rules (TEMPORARY USE ONLY):');
    print('   rules_version = \'2\';');
    print('   service cloud.firestore {');
    print('     match /databases/{database}/documents {');
    print('       match /{document=**} {');
    print('         allow read, write: if true;');
    print('       }');
    print('     }');
    print('   }');
  }
  
  print('\n✨ Seeding completed!');
  exit(0);
}