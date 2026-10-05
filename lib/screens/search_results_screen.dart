import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/firestore_collections.dart';
import '../models/accessibility_score.dart';
import '../models/search_place.dart';
import '../services/favorites_service.dart';
import '../services/location_service.dart';
import 'map_screen.dart';
import 'place_details_screen.dart';

enum _SearchSortMode {
  nearest('Nearest'),
  accessibility('Best score'),
  name('Name');

  const _SearchSortMode(this.label);
  final String label;
}

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({
    super.key,
    this.initialQuery = '',
    this.initialPlaces = const [],
    this.initialFilter,
    this.initialNearbyOnly = false,
    this.initialLocation,
    this.enableFavorites = false,
    this.locationService = const LocationService(),
    this.title = 'Search places',
    this.showSearchControls = true,
  });

  final String initialQuery;
  final List<Map<String, dynamic>> initialPlaces;
  final String? initialFilter;
  final bool initialNearbyOnly;
  final SearchPlaceLocation? initialLocation;
  final bool enableFavorites;
  final LocationService locationService;
  final String title;
  final bool showSearchControls;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _searchController;
  late final TextEditingController _locationController;
  List<SearchPlace> _places = const [];
  bool _isLoading = true;
  bool _isLoadingLocation = false;
  String? _loadError;
  String? _locationError;
  SearchPlaceLocation? _nearbyLocation;
  FavoritesService? _favoritesService;
  final Set<String> _selectedFilters = {};
  List<String> _recentSearches = const [];
  _SearchSortMode _sortMode = _SearchSortMode.nearest;
  String? _selectedCategory;
  late bool _nearbyOnly;

  static const _historyKey = 'search_discovery_history';

  static const _popularAreas = [
    'Colombo',
    'Gampaha',
    'Kandy',
    'Galle',
    'Matara',
    'Kurunegala',
    'Jaffna',
    'Negombo',
    'Nugegoda',
    'Maharagama',
    'Battaramulla',
    'Dehiwala',
  ];

  static const _filters = {
    'wheelchairaccessible': ('Wheelchair', Icons.accessible_forward),
    'accessibleparking': ('Parking', Icons.local_parking),
    'accessibletoilet': ('Toilet', Icons.wc),
    'audiosupport': ('Audio', Icons.volume_up),
    'elevator': ('Elevator', Icons.elevator),
    'hearingsupport': ('Hearing', Icons.hearing),
    'tactilepaving': ('Tactile', Icons.assistant),
  };

  List<SearchPlace> get _results {
    final query = _searchController.text.trim().toLowerCase();
    final locationQuery = _locationController.text.trim().toLowerCase();
    final matches = _places.where((place) {
      final matchesText =
          query.isEmpty ||
          place.name.toLowerCase().contains(query) ||
          place.category.toLowerCase().contains(query) ||
          place.address.toLowerCase().contains(query);
      final matchesLocation =
          locationQuery.isEmpty ||
          place.city.toLowerCase().contains(locationQuery) ||
          place.district.toLowerCase().contains(locationQuery) ||
          place.address.toLowerCase().contains(locationQuery);
      final matchesCategory =
          _selectedCategory == null || place.category == _selectedCategory;
      final matchesFilters = _selectedFilters.every(
        place.accessibilityFeatures.contains,
      );
      return matchesText &&
          matchesLocation &&
          matchesCategory &&
          matchesFilters;
    }).toList();

    final sortedPlaces = matches.toList();
    switch (_sortMode) {
      case _SearchSortMode.nearest:
        return searchPlacesSortedByDistance(
          sortedPlaces,
          from: _nearbyLocation ?? defaultSearchLocation,
        );
      case _SearchSortMode.accessibility:
        sortedPlaces.sort((first, second) {
          final firstScore = AccessibilityScore.fromPlace(first).percent;
          final secondScore = AccessibilityScore.fromPlace(second).percent;
          return secondScore.compareTo(firstScore);
        });
        return sortedPlaces;
      case _SearchSortMode.name:
        sortedPlaces.sort((first, second) => first.name.compareTo(second.name));
        return sortedPlaces;
    }
  }

  bool get _hasActiveSearch =>
      _searchController.text.trim().isNotEmpty ||
      _locationController.text.trim().isNotEmpty ||
      _selectedCategory != null ||
      _selectedFilters.isNotEmpty ||
      _nearbyOnly;

  bool get _showActiveSummary =>
      _activeFilterLabels.isNotEmpty &&
      !(_nearbyOnly &&
          _searchController.text.trim().isEmpty &&
          _locationController.text.trim().isEmpty &&
          _selectedCategory == null &&
          _selectedFilters.isEmpty);

  List<String> get _activeFilterLabels => [
    if (_nearbyOnly) 'Nearby',
    if (_locationController.text.trim().isNotEmpty)
      'Location: ${_locationController.text.trim()}',
    if (_selectedCategory != null) 'Category: $_selectedCategory',
    for (final filter in _selectedFilters) _filters[filter]?.$1 ?? filter,
  ];

  String get _areaLabel {
    if (_nearbyOnly) return 'Near me';
    final area = _locationController.text.trim();
    if (area.isNotEmpty) return area;
    return 'Any area';
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _locationController = TextEditingController();
    _nearbyOnly = widget.initialNearbyOnly;
    _nearbyLocation = widget.initialLocation;
    if (widget.enableFavorites) {
      _favoritesService = FavoritesService();
    }
    if (widget.initialFilter != null) {
      _selectedFilters.add(widget.initialFilter!);
    }
    _places = widget.initialPlaces
        .map(SearchPlace.fromData)
        .whereType<SearchPlace>()
        .toList();
    if (widget.initialPlaces.isNotEmpty) {
      _isLoading = false;
    } else {
      _loadPlaces();
    }
    if (_nearbyOnly && _nearbyLocation == null) {
      _requestCurrentLocation();
    }
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _recentSearches = preferences.getStringList(_historyKey) ?? const [];
      });
    } catch (_) {
      // Search still works if local history storage is unavailable.
    }
  }

  Future<void> _recordSearch({String? value}) async {
    final term = (value ?? _searchController.text).trim();
    if (term.length < 2) return;

    final updated = [
      term,
      ..._recentSearches.where(
        (item) => item.toLowerCase() != term.toLowerCase(),
      ),
    ].take(6).toList();

    setState(() => _recentSearches = updated);

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_historyKey, updated);
    } catch (_) {
      // Keep in-memory history for this session.
    }
  }

  Future<void> _loadPlaces() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.places)
          .get();
      final places = snapshot.docs
          .map(SearchPlace.fromFirestore)
          .whereType<SearchPlace>()
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
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final locationQuery = _locationController.text.trim();
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.title),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showSearchControls) ...[
                      TextField(
                        autofocus: widget.initialQuery.isEmpty,
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          _recordSearch();
                          setState(() {});
                        },
                        textInputAction: TextInputAction.search,
                        decoration: _searchDecoration(
                          hasText: query.isNotEmpty,
                          onClear: _clearSearchQuery,
                        ),
                      ),
                      if (query.isEmpty && _recentSearches.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _InlineSearchHistory(
                          searches: _recentSearches,
                          onSelected: _applyHistorySearch,
                          onClearAll: _clearSearchHistory,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _SearchAreaSelector(
                        label: _areaLabel,
                        isNearby: _nearbyOnly,
                        hasSelectedArea: locationQuery.isNotEmpty,
                        onUseNearby: () => _toggleNearbyOnly(true),
                        onChooseArea: _openAreaPicker,
                        onOpenMap: _openMap,
                        onClearArea: _clearLocationQuery,
                      ),
                    ] else ...[
                      _NearbyStatusCard(
                        hasLocation: _nearbyLocation != null,
                        isLoading: _isLoadingLocation,
                        onRefresh: _requestCurrentLocation,
                        onOpenMap: _openMap,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _SearchToolsRow(
                      hasActiveFilters:
                          _selectedCategory != null ||
                          _selectedFilters.isNotEmpty ||
                          _nearbyOnly,
                      onOpenFilters: _openFilterList,
                    ),
                    if (_showActiveSummary) ...[
                      const SizedBox(height: 12),
                      _ActiveSearchSummary(
                        labels: _activeFilterLabels,
                        onClear: _clearSearch,
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_hasActiveSearch) ...[
                      _ResultsHeader(
                        title: _nearbyOnly ? 'Nearby places' : 'Search results',
                        count: _results.length,
                        sortMode: _sortMode,
                        onSortChanged: (mode) {
                          if (mode == null) return;
                          setState(() => _sortMode = mode);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Expanded(child: _content(query, locationQuery)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(String query, String locationQuery) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_nearbyOnly && _isLoadingLocation) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _LoadError(message: _loadError!, onRetry: _retry);
    }
    if (_nearbyOnly && _locationError != null) {
      return _LoadError(
        message: _locationError!,
        onRetry: _requestCurrentLocation,
      );
    }
    if (query.isEmpty &&
        locationQuery.isEmpty &&
        _selectedCategory == null &&
        _selectedFilters.isEmpty &&
        !_nearbyOnly) {
      return _SearchPrompt(
        recentSearches: _recentSearches,
        onSearchSelected: _applyHistorySearch,
      );
    }
    if (_results.isEmpty) {
      return _NoResults(
        query: query.isNotEmpty ? query : locationQuery,
        suggestions: _suggestedSearches,
        onClear: _clearSearch,
        onSuggestionSelected: _applyHistorySearch,
      );
    }
    final favoritesService = _favoritesService;
    if (favoritesService != null) {
      return StreamBuilder<Set<String>>(
        stream: favoritesService.favoriteIds(),
        builder: (context, snapshot) {
          final favoriteIds = snapshot.data ?? <String>{};
          return _ResultList(
            places: _results,
            favoriteIds: favoriteIds,
            onToggleFavorite: _toggleFavorite,
            onOpenDetails: (place) => Navigator.push(
              context,
              PlaceDetailsScreen.route(placeId: place.id),
            ),
          );
        },
      );
    }

    return _ResultList(
      places: _results,
      onOpenDetails: (place) =>
          Navigator.push(context, PlaceDetailsScreen.route(placeId: place.id)),
    );
  }

  Future<void> _toggleFavorite(SearchPlace place, bool isSaved) async {
    final favoritesService = _favoritesService;
    if (favoritesService == null) return;

    try {
      await favoritesService.toggleFavorite(place, isSaved);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSaved ? 'Removed from saved places' : 'Saved to favourites',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _locationController.clear();
    _selectedCategory = null;
    _selectedFilters.clear();
    _nearbyOnly = false;
    setState(() {});
  }

  void _clearSearchQuery() {
    _searchController.clear();
    setState(() {});
  }

  void _clearLocationQuery() {
    _locationController.clear();
    _nearbyOnly = false;
    setState(() {});
  }

  Future<void> _clearSearchHistory() async {
    setState(() => _recentSearches = const []);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_historyKey);
    } catch (_) {
      // Clearing the visible history is enough if storage is unavailable.
    }
  }

  void _applyHistorySearch(String value) {
    _searchController.text = value;
    _recordSearch(value: value);
    setState(() {});
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
    });
  }

  void _selectLocation(String location) {
    _locationController.text = location;
    _nearbyOnly = false;
    setState(() {});
  }

  List<String> get _locationOptions {
    final locations = <String>{};
    for (final place in _places) {
      if (place.city.isNotEmpty) locations.add(place.city);
      if (place.district.isNotEmpty) locations.add(place.district);
    }
    return (locations.toList()..sort()).take(8).toList();
  }

  List<String> get _areaOptions {
    final seen = <String>{};
    return [
      for (final area in [..._locationOptions, ..._popularAreas])
        if (area.trim().isNotEmpty && seen.add(area.trim().toLowerCase()))
          area.trim(),
    ];
  }

  List<String> get _categoryOptions {
    final categories = {
      for (final place in _places)
        if (place.category.trim().isNotEmpty) place.category.trim(),
    };
    return (categories.toList()..sort()).take(8).toList();
  }

  List<String> get _suggestedSearches {
    final suggestions = <String>[
      ..._recentSearches,
      ..._categoryOptions,
      ..._locationOptions,
      'Hospital',
      'Restaurant',
      'Park',
      'Bank',
    ];
    final seen = <String>{};
    return [
      for (final suggestion in suggestions)
        if (suggestion.trim().isNotEmpty &&
            seen.add(suggestion.trim().toLowerCase()))
          suggestion.trim(),
    ].take(8).toList();
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (!_selectedFilters.add(filter)) {
        _selectedFilters.remove(filter);
      }
    });
  }

  void _toggleNearbyOnly(bool selected) {
    setState(() {
      _nearbyOnly = selected;
      _locationError = null;
      if (selected) {
        _locationController.clear();
      }
    });

    if (selected && _nearbyLocation == null) {
      _requestCurrentLocation();
    }
  }

  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  }

  Future<void> _openAreaPicker() async {
    var query = '';

    final selectedArea = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final visibleAreas = _areaOptions.where((area) {
              return query.isEmpty ||
                  area.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close area picker',
                      ),
                      Expanded(
                        child: Text(
                          'Choose search area',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, ''),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search district or city',
                      prefixIcon: Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final area in visibleAreas)
                        ChoiceChip(
                          avatar: const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                          ),
                          label: Text(area),
                          selected: _locationController.text == area,
                          onSelected: (_) => Navigator.pop(context, area),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || selectedArea == null) return;
    if (selectedArea.isEmpty) {
      _clearLocationQuery();
    } else {
      _selectLocation(selectedArea);
    }
  }

  Future<void> _requestCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    final result = await widget.locationService.currentLocation();
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = false;
      _nearbyLocation = result.location;
      _locationError = result.errorMessage;
    });
  }

  Future<void> _openFilterList() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close filters',
                      ),
                      Expanded(
                        child: Text(
                          'Filters',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _nearbyOnly = false;
                            _selectedCategory = null;
                            _selectedFilters.clear();
                            _locationController.clear();
                          });
                          setSheetState(() {});
                        },
                        child: const Text('Clear'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _nearbyOnly,
                    secondary: const Icon(Icons.near_me_outlined),
                    title: const Text('Nearby places'),
                    subtitle: const Text('Sort results from your location'),
                    onChanged: (selected) {
                      _toggleNearbyOnly(selected);
                      setSheetState(() {});
                    },
                  ),
                  if (_locationOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'District or city',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final location in _locationOptions)
                          ChoiceChip(
                            avatar: const Icon(
                              Icons.location_city_outlined,
                              size: 16,
                            ),
                            label: Text(location),
                            selected: _locationController.text == location,
                            onSelected: (_) {
                              _selectLocation(location);
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                  ],
                  if (_categoryOptions.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Category',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in _categoryOptions)
                          ChoiceChip(
                            avatar: Icon(
                              iconForSearchCategory(category),
                              size: 17,
                            ),
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (_) {
                              _selectCategory(category);
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Accessibility',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
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

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.places,
    this.favoriteIds = const {},
    this.onToggleFavorite,
    this.onOpenDetails,
  });

  final List<SearchPlace> places;
  final Set<String> favoriteIds;
  final Future<void> Function(SearchPlace place, bool isSaved)?
  onToggleFavorite;
  final void Function(SearchPlace place)? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: places.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final place = places[index];
        return _ResultTile(
          place: place,
          isSaved: favoriteIds.contains(place.id),
          onToggleFavorite: onToggleFavorite,
          onOpenDetails: onOpenDetails,
        );
      },
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.title,
    required this.count,
    required this.sortMode,
    required this.onSortChanged,
  });

  final String title;
  final int count;
  final _SearchSortMode sortMode;
  final ValueChanged<_SearchSortMode?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '$count accessible ${count == 1 ? 'place' : 'places'} found',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<_SearchSortMode>(
            value: sortMode,
            borderRadius: BorderRadius.circular(12),
            icon: const Icon(Icons.sort),
            items: [
              for (final mode in _SearchSortMode.values)
                DropdownMenuItem(value: mode, child: Text(mode.label)),
            ],
            onChanged: onSortChanged,
          ),
        ),
      ],
    );
  }
}

class _SearchToolsRow extends StatelessWidget {
  const _SearchToolsRow({
    required this.hasActiveFilters,
    required this.onOpenFilters,
  });

  final bool hasActiveFilters;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            hasActiveFilters
                ? 'Filters are shaping these results'
                : 'Use filters to narrow your search',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onOpenFilters,
          icon: Icon(
            hasActiveFilters ? Icons.filter_alt : Icons.tune,
            size: 17,
          ),
          label: const Text('Filters'),
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }
}

class _SearchAreaSelector extends StatelessWidget {
  const _SearchAreaSelector({
    required this.label,
    required this.isNearby,
    required this.hasSelectedArea,
    required this.onUseNearby,
    required this.onChooseArea,
    required this.onOpenMap,
    required this.onClearArea,
  });

  final String label;
  final bool isNearby;
  final bool hasSelectedArea;
  final VoidCallback onUseNearby;
  final VoidCallback onChooseArea;
  final VoidCallback onOpenMap;
  final VoidCallback onClearArea;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search area: $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (isNearby || hasSelectedArea)
                IconButton(
                  onPressed: onClearArea,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Clear search area',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.my_location, size: 16),
                label: const Text('Near me'),
                selected: isNearby,
                onSelected: (_) => onUseNearby(),
              ),
              ActionChip(
                avatar: const Icon(Icons.location_city_outlined, size: 16),
                label: const Text('Choose area'),
                onPressed: onChooseArea,
              ),
              ActionChip(
                avatar: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Map'),
                onPressed: onOpenMap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NearbyStatusCard extends StatelessWidget {
  const _NearbyStatusCard({
    required this.hasLocation,
    required this.isLoading,
    required this.onRefresh,
    required this.onOpenMap,
  });

  final bool hasLocation;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasLocation ? Icons.my_location : Icons.location_searching,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation
                      ? 'Showing places near you'
                      : 'Finding places near you',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasLocation
                      ? 'Results are sorted using your latest location.'
                      : 'Location permission may be requested if needed.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.78,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isLoading ? null : onRefresh,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            color: colorScheme.onPrimaryContainer,
            tooltip: 'Refresh current location',
          ),
          IconButton(
            onPressed: onOpenMap,
            icon: const Icon(Icons.map_outlined),
            color: colorScheme.onPrimaryContainer,
            tooltip: 'Open map',
          ),
        ],
      ),
    );
  }
}

class _ActiveSearchSummary extends StatelessWidget {
  const _ActiveSearchSummary({required this.labels, required this.onClear});

  final List<String> labels;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_outlined, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final label in labels) ...[
                    Chip(
                      label: Text(label),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _SearchSuggestionChips extends StatelessWidget {
  const _SearchSuggestionChips({
    required this.title,
    required this.suggestions,
    required this.onSelected,
  });

  final String title;
  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in suggestions)
              ActionChip(
                avatar: const Icon(Icons.history, size: 16),
                label: Text(suggestion),
                onPressed: () => onSelected(suggestion),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ],
    );
  }
}

class _InlineSearchHistory extends StatelessWidget {
  const _InlineSearchHistory({
    required this.searches,
    required this.onSelected,
    required this.onClearAll,
  });

  final List<String> searches;
  final ValueChanged<String> onSelected;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Recent',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final search in searches) ...[
                    ActionChip(
                      label: Text(search),
                      onPressed: () => onSelected(search),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onClearAll,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Clear search history',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

InputDecoration _searchDecoration({
  required bool hasText,
  required VoidCallback onClear,
}) => InputDecoration(
  hintText: 'Search accessible places',
  prefixIcon: const Icon(Icons.search),
  suffixIcon: hasText
      ? IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.clear),
          tooltip: 'Clear search',
        )
      : null,
  border: const OutlineInputBorder(),
);

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.place,
    this.isSaved = false,
    this.onToggleFavorite,
    this.onOpenDetails,
  });

  final SearchPlace place;
  final bool isSaved;
  final Future<void> Function(SearchPlace place, bool isSaved)?
  onToggleFavorite;
  final void Function(SearchPlace place)? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'View details for ${place.name}',
      child: InkWell(
        onTap: onOpenDetails == null ? null : () => onOpenDetails!(place),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  place.icon,
                  size: 25,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${place.category} . ${place.distance}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    if (AccessibilityScore.fromPlace(place).canShow) ...[
                      const SizedBox(height: 6),
                      _AccessibilityScoreBadge(place: place),
                    ],
                    if (place.locationLabel.isNotEmpty)
                      Text(
                        place.locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                  ],
                ),
              ),
              if (onToggleFavorite != null)
                IconButton(
                  onPressed: () => onToggleFavorite!(place, isSaved),
                  icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border),
                  color: isSaved ? colorScheme.error : colorScheme.primary,
                  tooltip: isSaved ? 'Remove from saved places' : 'Save place',
                ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessibilityScoreBadge extends StatelessWidget {
  const _AccessibilityScoreBadge({required this.place});

  final SearchPlace place;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        AccessibilityScore.fromPlace(place).label,
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt({
    required this.recentSearches,
    required this.onSearchSelected,
  });

  final List<String> recentSearches;
  final ValueChanged<String> onSearchSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        _StateMessage(
          icon: Icons.travel_explore,
          title: 'Find accessible places',
          message: 'Enter a place name, category, district, or city above.',
        ),
        if (recentSearches.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SearchSuggestionChips(
            title: 'Recent searches',
            suggestions: recentSearches,
            onSelected: onSearchSelected,
          ),
        ],
      ],
    ),
  );
}

class _NoResults extends StatelessWidget {
  const _NoResults({
    required this.query,
    required this.suggestions,
    required this.onClear,
    required this.onSuggestionSelected,
  });

  final String query;
  final List<String> suggestions;
  final VoidCallback onClear;
  final ValueChanged<String> onSuggestionSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        _StateMessage(
          icon: Icons.search_off,
          title: 'No accessible places found',
          message: 'We could not find a public place matching "$query".',
          action: OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.refresh),
            label: const Text('Clear search'),
          ),
        ),
        const SizedBox(height: 16),
        _SearchSuggestionChips(
          title: 'Try one of these',
          suggestions: suggestions,
          onSelected: onSuggestionSelected,
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
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: _StateMessage(
        icon: Icons.cloud_off,
        title: 'Places could not be loaded',
        message: message,
        isError: true,
        action: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ),
    ),
  );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isError ? colorScheme.error : colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.hasBoundedHeight && constraints.maxHeight < 180;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 12 : 24),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ...[
                Icon(icon, size: 48, color: iconColor),
                const SizedBox(height: 14),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 18), action!],
              ],
            ],
          ),
        );
      },
    );
  }
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
