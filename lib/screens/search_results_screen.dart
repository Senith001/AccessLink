import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/database/firestore_collections.dart';
import '../models/place.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({
    super.key,
    this.initialQuery = '',
    this.initialPlaces = const [],
    this.initialFilter,
  });

  final String initialQuery;
  final List<Map<String, dynamic>> initialPlaces;
  final String? initialFilter;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _searchController;
  List<Place> _places = const [];
  bool _isLoading = true;
  String? _loadError;
  final Set<String> _selectedFilters = {};

  static const _filters = {
    'wheelchairaccessible': ('Wheelchair', Icons.accessible_forward),
    'accessibleparking': ('Parking', Icons.local_parking),
    'accessibletoilet': ('Toilet', Icons.wc),
    'audiosupport': ('Audio', Icons.volume_up),
    'elevator': ('Elevator', Icons.elevator),
    'hearingsupport': ('Hearing', Icons.hearing),
    'tactilepaving': ('Tactile', Icons.assistant),
  };

  static const _quickFilters = [
    'wheelchairaccessible',
    'accessibleparking',
    'accessibletoilet',
    'audiosupport',
    'elevator',
    'hearingsupport',
    'tactilepaving',
  ];

  List<Place> get _results {
    final query = _searchController.text.trim().toLowerCase();
    return _places.where((place) {
      final matchesText =
          query.isEmpty ||
          place.name.toLowerCase().contains(query) ||
          place.category.toLowerCase().contains(query) ||
          place.address.toLowerCase().contains(query);
      final matchesFilters = _selectedFilters.every(
        place.accessibilityFeatures.contains,
      );
      return matchesText && matchesFilters;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    if (widget.initialFilter != null) {
      _selectedFilters.add(widget.initialFilter!);
    }
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
        _loadError =
            'Unable to load places. Check your connection and try again.';
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
                    const SizedBox(height: 12),
                    _FilterControls(
                      filters: _filters,
                      quickFilters: _quickFilters,
                      selectedFilters: _selectedFilters,
                      onChanged: _toggleFilter,
                      onOpenFilterList: _openFilterList,
                    ),
                    const SizedBox(height: 22),
                    if (query.isNotEmpty || _selectedFilters.isNotEmpty) ...[
                      const Text(
                        'Search results',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
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
    if (query.isEmpty && _selectedFilters.isEmpty) {
      return const _SearchPrompt();
    }
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

  void _toggleFilter(String filter) {
    setState(() {
      if (!_selectedFilters.add(filter)) {
        _selectedFilters.remove(filter);
      }
    });
  }

  Future<void> _openFilterList() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  const Text(
                    'Accessibility filters',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in _filters.entries)
                    CheckboxListTile(
                      value: _selectedFilters.contains(entry.key),
                      secondary: Icon(entry.value.$2),
                      title: Text(entry.value.$1),
                      onChanged: (_) {
                        _toggleFilter(entry.key);
                        setSheetState(() {});
                      },
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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

class _FilterControls extends StatelessWidget {
  const _FilterControls({
    required this.filters,
    required this.quickFilters,
    required this.selectedFilters,
    required this.onChanged,
    required this.onOpenFilterList,
  });

  final Map<String, (String, IconData)> filters;
  final List<String> quickFilters;
  final Set<String> selectedFilters;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenFilterList;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Accessibility',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onOpenFilterList,
              icon: const Icon(Icons.tune, size: 17),
              label: const Text('Filters'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: quickFilters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final key = quickFilters[index];
              final filter = filters[key]!;
              return FilterChip(
                avatar: Icon(filter.$2, size: 17),
                label: Text(filter.$1),
                selected: selectedFilters.contains(key),
                onSelected: (_) => onChanged(key),
                selectedColor: const Color(0xFFBDE8F0),
                checkmarkColor: const Color(0xFF2C4552),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
      ],
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
                Text('${place.category} . ${place.distance}'),
                if (place.address.isNotEmpty)
                  Text(place.address, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
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
        const Text(
          'No accessible places found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'We could not find a public place matching "$query".',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.refresh),
          label: const Text('Clear search'),
        ),
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
        const Text(
          'Places could not be loaded',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
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
