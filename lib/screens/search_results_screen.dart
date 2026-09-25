import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/database/firestore_collections.dart';
import '../models/place.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({
    super.key,
    this.initialQuery = '',
    this.initialPlaces = const [],
  });

  final String initialQuery;
  final List<Map<String, dynamic>> initialPlaces;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _searchController;
  List<Place> _places = const [];
  bool _isLoading = true;
  String? _loadError;

  List<Place> get _results {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _places;
    return _places.where((place) {
      return place.name.toLowerCase().contains(query) ||
          place.category.toLowerCase().contains(query) ||
          place.address.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _places = widget.initialPlaces
        .map(Place.fromData)
        .whereType<Place>()
        .toList();
    if (widget.initialPlaces.isNotEmpty) {
      _isLoading = false;
    } else {
      _loadPlaces();
    }
  }

  Future<void> _loadPlaces() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.places)
          .get();
      final places = snapshot.docs
          .map(Place.fromFirestore)
          .whereType<Place>()
          .toList();
      if (!mounted) return;
      setState(() {
        _places = places;
        _isLoading = false;
        _loadError = null;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _firestoreErrorMessage(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load places. Check your connection and try again.';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    return Scaffold(
      backgroundColor: const Color(0xFF62A4C6),
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(onBack: () => Navigator.pop(context)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      autofocus: widget.initialQuery.isEmpty,
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: _searchDecoration(),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      query.isEmpty ? 'Nearby places' : 'Search results',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: _content(query)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(String query) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _LoadError(message: _loadError!, onRetry: _retry);
    }
    if (query.isEmpty) return const _SearchPrompt();
    if (_results.isEmpty) {
      return _NoResults(query: query, onClear: _clearSearch);
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ResultTile(place: _results[index]),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    _loadPlaces();
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({required this.onBack});
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
              'Search places',
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

InputDecoration _searchDecoration() => InputDecoration(
      hintText: 'Search accessible places',
      prefixIcon: const Icon(Icons.search, color: Color(0xFF009BC2)),
      suffixIcon: const Icon(Icons.clear),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFE4E7EA)),
        borderRadius: BorderRadius.circular(9),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF62A4C6), width: 2),
        borderRadius: BorderRadius.circular(9),
      ),
    );

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.place});
  final Place place;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PlaceDetailsScreen(place: place)),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
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
                  Text(place.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${place.category} . ${place.distance}'),
                  if (place.address.isNotEmpty) Text(place.address, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class PlaceDetailsScreen extends StatelessWidget {
  const PlaceDetailsScreen({super.key, required this.place});
  final Place place;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF62A4C6),
      appBar: AppBar(
        title: Text(place.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: ListView(
          children: [
            Container(
              height: 170,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F2F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(place.icon, size: 76, color: const Color(0xFF62A4C6)),
            ),
            const SizedBox(height: 22),
            Text(place.name, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(place.category, style: const TextStyle(color: Color(0xFF62A4C6), fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            _Detail(label: 'Address', value: place.address.isEmpty ? 'Address not available' : place.address),
            const SizedBox(height: 16),
            _Detail(
              label: 'Coordinates',
              value: place.latitude == null || place.longitude == null
                  ? 'Location not available'
                  : '${place.latitude}, ${place.longitude}',
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value),
        ],
      );
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();
  @override
  Widget build(BuildContext context) => const Center(
        child: Text(
          'Enter a place name, category, or address above.',
          textAlign: TextAlign.center,
        ),
      );
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.onClear});
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 46, color: Color(0xFF62A4C6)),
            const SizedBox(height: 14),
            const Text('No accessible places found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('We could not find a public place matching "$query".', textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: onClear, icon: const Icon(Icons.refresh), label: const Text('Clear search')),
          ],
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Color(0xFFFF0033)),
            const SizedBox(height: 14),
            const Text('Places could not be loaded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ],
        ),
      );
}

String _firestoreErrorMessage(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'Firebase denied access to the places collection. Check Firestore rules.';
    case 'unavailable':
      return 'Firebase is unavailable. Check your internet connection.';
    default:
      return error.message == null || error.message!.isEmpty
          ? 'Firebase could not load places (${error.code}).'
          : 'Firebase could not load places: ${error.message}';
  }
}
