import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/database/firestore_collections.dart';
import '../models/place.dart';
import '../models/saved_place.dart';

class FavoritesService {
  FavoritesService({this.auth, this.firestore});

  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  FirebaseAuth get _firebaseAuth => auth ?? FirebaseAuth.instance;

  FirebaseFirestore get _firebaseFirestore =>
      firestore ?? FirebaseFirestore.instance;

  User? get currentUser {
    try {
      return _firebaseAuth.currentUser;
    } on FirebaseException {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _favoritesCollection {
    final user = currentUser;
    if (user == null) return null;

    try {
      return _firebaseFirestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .collection('favorite_places');
    } on FirebaseException {
      return null;
    }
  }

  Stream<Set<String>> favoriteIds() {
    final collection = _favoritesCollection;
    if (collection == null) return Stream.value(<String>{});

    return collection.snapshots().map(
      (snapshot) => snapshot.docs.map((document) => document.id).toSet(),
    );
  }

  Stream<List<SavedPlace>> favoritePlaces() {
    final collection = _favoritesCollection;
    if (collection == null) return Stream.value(const <SavedPlace>[]);

    return collection
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    SavedPlace.fromData(document.data(), id: document.id),
              )
              .whereType<SavedPlace>()
              .toList(),
        );
  }

  Future<void> addFavorite(Place place) async {
    final collection = _favoritesCollection;
    if (collection == null) {
      throw StateError('Please log in to save favourite places.');
    }

    await collection.doc(place.id).set({
      ...SavedPlace.fromPlace(place).toData(),
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFavorite(Place place) async {
    return removeFavoriteById(place.id);
  }

  Future<void> removeFavoriteById(String placeId) async {
    final collection = _favoritesCollection;
    if (collection == null) {
      throw StateError('Please log in to remove favourite places.');
    }

    await collection.doc(placeId).delete();
  }

  Future<void> toggleFavorite(Place place, bool isSaved) {
    return isSaved ? removeFavorite(place) : addFavorite(place);
  }
}
