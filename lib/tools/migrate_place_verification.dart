/// Run manually against a chosen environment; do not run against production without explicit approval.
/// 
/// Migration script to add explicit place-level verification fields to existing places.
/// This script is idempotent and conservative - it sets placeVerified=false by default
/// and does NOT trust legacy isVerified=true as a deliberate verification.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../core/database/firestore_collections.dart';
import '../firebase_options.dart';

Future<void> main() async {
  // Initialize Flutter bindings and Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final firestore = FirebaseFirestore.instance;
  
  // Print banner
  print('=' * 70);
  print('🔄 MIGRATING PLACE VERIFICATION FIELDS');
  print('📦 Project: access-link-005');
  print('⚠️  Mode: CONSERVATIVE (sets placeVerified=false for all places)');
  print('🔒 Safe: Uses merge operations - idempotent');
  print('🚫 Does NOT trust legacy isVerified=true as staff verification');
  print('=' * 70);
  print('');
  
  // Confirm user wants to proceed
  print('This migration will:');
  print('1. Add placeVerified=false to all places missing this field');
  print('2. Log places that had isVerified=true for staff review');
  print('3. NOT modify any existing placeVerified values');
  print('');
  stdout.write('Continue? (y/N): ');
  final input = stdin.readLineSync()?.toLowerCase().trim() ?? '';
  
  if (input != 'y' && input != 'yes') {
    print('Migration cancelled.');
    exit(0);
  }
  
  print('');
  print('🔍 Scanning places collection...');
  
  // Track migration results
  int processedCount = 0;
  int migratedCount = 0;
  int legacyVerifiedCount = 0;
  final legacyVerifiedPlaces = <String>[];
  final errors = <String>[];
  
  try {
    // Get all places documents
    final placesQuery = firestore.collection(FirestoreCollections.places);
    final querySnapshot = await placesQuery.get();
    
    print('Found ${querySnapshot.docs.length} places to process.');
    print('');
    
    // Process each place document
    for (final doc in querySnapshot.docs) {
      processedCount++;
      final data = doc.data();
      final placeName = data['name'] as String? ?? doc.id;
      
      try {
        final hasPlaceVerified = data.containsKey('placeVerified');
        final legacyIsVerified = data['isVerified'] as bool? ?? false;
        
        // Log if legacy isVerified was true for staff review
        if (legacyIsVerified) {
          legacyVerifiedCount++;
          legacyVerifiedPlaces.add('$placeName (${doc.id})');
        }
        
        // Only migrate if placeVerified field is missing
        if (!hasPlaceVerified) {
          await doc.reference.set({
            'placeVerified': false,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          migratedCount++;
          print('  ✅ Migrated: $placeName');
        } else {
          print('  ⏭️  Skipped: $placeName (already has placeVerified)');
        }
        
      } catch (e) {
        final error = 'Failed to migrate $placeName (${doc.id}): $e';
        errors.add(error);
        print('  ❌ $error');
      }
    }
    
  } catch (e) {
    print('❌ Query failed: $e');
    exit(1);
  }
  
  // Print migration summary
  print('');
  print('=' * 70);
  print('📊 MIGRATION SUMMARY');
  print('=' * 70);
  print('📁 Total places processed: $processedCount');
  print('✅ Places migrated (added placeVerified=false): $migratedCount');
  print('⏭️  Places already had placeVerified: ${processedCount - migratedCount}');
  
  if (legacyVerifiedCount > 0) {
    print('');
    print('⚠️  STAFF REVIEW REQUIRED:');
    print('📋 $legacyVerifiedCount places had legacy isVerified=true:');
    for (final place in legacyVerifiedPlaces) {
      print('   • $place');
    }
    print('');
    print('🔍 These places may need manual staff verification review.');
    print('📝 The migration did NOT trust isVerified=true as deliberate verification.');
  }
  
  if (errors.isNotEmpty) {
    print('');
    print('❌ ERRORS (${errors.length}):');
    for (final error in errors) {
      print('   • $error');
    }
  }
  
  print('');
  print('✨ Migration completed!');
  print('💡 All places now have placeVerified field (defaulted to false)');
  print('👥 Staff can now use admin tools to set placeVerified=true as needed');
  
  exit(errors.isNotEmpty ? 1 : 0);
}