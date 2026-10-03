import 'package:flutter/material.dart';

import '../models/saved_place.dart';
import '../services/favorites_service.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  final FavoritesService _favoritesService = FavoritesService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF62A4C6),
      body: SafeArea(
        child: Column(
          children: [
            _SavedHeader(onBack: () => Navigator.pop(context)),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                ),
                child: StreamBuilder<List<SavedPlace>>(
                  stream: _favoritesService.favoritePlaces(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _SavedPlacesError(
                        message: snapshot.error.toString(),
                      );
                    }

                    final places = snapshot.data ?? const <SavedPlace>[];
                    if (places.isEmpty) {
                      return const _EmptySavedPlaces();
                    }

                    return ListView.separated(
                      itemCount: places.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final place = places[index];
                        return _SavedPlaceTile(
                          place: place,
                          onRemove: () => _removeFavorite(place),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeFavorite(SavedPlace place) async {
    await _favoritesService.removeFavoriteById(place.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Removed from saved places')));
  }
}

class _SavedHeader extends StatelessWidget {
  const _SavedHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 18, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            color: Colors.black,
            tooltip: 'Back',
          ),
          const Expanded(
            child: Text(
              'Saved places',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Georgia', fontSize: 25),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SavedPlaceTile extends StatelessWidget {
  const _SavedPlaceTile({required this.place, required this.onRemove});

  final SavedPlace place;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFC),
        border: Border.all(color: const Color(0xFFE4E7EA)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(place.icon, size: 42, color: const Color(0xFF62A4C6)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(place.category),
                if (place.locationLabel.isNotEmpty)
                  Text(
                    place.locationLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.favorite, color: Color(0xFFFF0033)),
            tooltip: 'Remove from saved places',
          ),
        ],
      ),
    );
  }
}

class _EmptySavedPlaces extends StatelessWidget {
  const _EmptySavedPlaces();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No saved places yet.', textAlign: TextAlign.center),
    );
  }
}

class _SavedPlacesError extends StatelessWidget {
  const _SavedPlacesError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}
