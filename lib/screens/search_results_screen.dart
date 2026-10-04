import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/database/firestore_collections.dart';
import '../models/accessibility_score.dart';
import '../models/search_place.dart';
import '../services/favorites_service.dart';
import '../services/location_service.dart';
import 'place_details_screen.dart';

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
  });

  final String initialQuery;
  final List<Map<String, dynamic>> initialPlaces;
  final String? initialFilter;
  final bool initialNearbyOnly;
  final SearchPlaceLocation? initialLocation;
  final bool enableFavorites;
  final LocationService locationService;

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
  String? _selectedCategory;
  late bool _nearbyOnly;

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

    if (_nearbyOnly) {
      return searchPlacesSortedByDistance(
        matches,
        from: _nearbyLocation ?? defaultSearchLocation,
      );
    }

    return matches;
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
        title: const Text('Search places'),
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
                    TextField(
                      autofocus: widget.initialQuery.isEmpty,
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: _searchDecoration(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: _locationSearchDecoration(),
                    ),
                    if (_locationOptions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _LocationQuickFilters(
                        locations: _locationOptions,
                        selectedLocation: locationQuery,
                        onSelected: _selectLocation,
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_categoryOptions.isNotEmpty) ...[
                      _CategoryFilterControls(
                        categories: _categoryOptions,
                        selectedCategory: _selectedCategory,
                        onSelected: _selectCategory,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _FilterControls(
                      filters: _filters,
                      quickFilters: _quickFilters,
                      selectedFilters: _selectedFilters,
                      nearbyOnly: _nearbyOnly,
                      onChanged: _toggleFilter,
                      onNearbyChanged: _toggleNearbyOnly,
                      onOpenFilterList: _openFilterList,
                    ),
                    const SizedBox(height: 22),
                    if (query.isNotEmpty ||
                        locationQuery.isNotEmpty ||
                        _selectedCategory != null ||
                        _selectedFilters.isNotEmpty ||
                        _nearbyOnly) ...[
                      Text(
                        _nearbyOnly ? 'Nearby places' : 'Search results',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
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
      return const _SearchPrompt();
    }
    if (_results.isEmpty) {
      return _NoResults(query: query, onClear: _clearSearch);
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
    setState(() {});
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
    });
  }

  void _selectLocation(String location) {
    _locationController.text = location;
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

  List<String> get _categoryOptions {
    final categories = {
      for (final place in _places)
        if (place.category.trim().isNotEmpty) place.category.trim(),
    };
    return (categories.toList()..sort()).take(8).toList();
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
    });

    if (selected && _nearbyLocation == null) {
      _requestCurrentLocation();
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

class _FilterControls extends StatelessWidget {
  const _FilterControls({
    required this.filters,
    required this.quickFilters,
    required this.selectedFilters,
    required this.nearbyOnly,
    required this.onChanged,
    required this.onNearbyChanged,
    required this.onOpenFilterList,
  });

  final Map<String, (String, IconData)> filters;
  final List<String> quickFilters;
  final Set<String> selectedFilters;
  final bool nearbyOnly;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onNearbyChanged;
  final VoidCallback onOpenFilterList;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Accessibility',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
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
            itemCount: quickFilters.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return FilterChip(
                  avatar: const Icon(Icons.near_me_outlined, size: 17),
                  label: const Text('Nearby'),
                  selected: nearbyOnly,
                  onSelected: onNearbyChanged,
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.onPrimaryContainer,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }

              final key = quickFilters[index - 1];
              final filter = filters[key]!;
              return FilterChip(
                avatar: Icon(filter.$2, size: 17),
                label: Text(filter.$1),
                selected: selectedFilters.contains(key),
                onSelected: (_) => onChanged(key),
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.onPrimaryContainer,
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

class _LocationQuickFilters extends StatelessWidget {
  const _LocationQuickFilters({
    required this.locations,
    required this.selectedLocation,
    required this.onSelected,
  });

  final List<String> locations;
  final String selectedLocation;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: locations.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final location = locations[index];
          return ChoiceChip(
            avatar: const Icon(Icons.location_city_outlined, size: 16),
            label: Text(location),
            selected: selectedLocation == location,
            onSelected: (_) => onSelected(location),
            selectedColor: colorScheme.primaryContainer,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class _CategoryFilterControls extends StatelessWidget {
  const _CategoryFilterControls({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ChoiceChip(
                avatar: Icon(iconForSearchCategory(category), size: 17),
                label: Text(category),
                selected: selectedCategory == category,
                onSelected: (_) => onSelected(category),
                selectedColor: colorScheme.primaryContainer,
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

InputDecoration _searchDecoration() => const InputDecoration(
  hintText: 'Search accessible places',
  prefixIcon: Icon(Icons.search),
  suffixIcon: Icon(Icons.clear),
  border: OutlineInputBorder(),
);

InputDecoration _locationSearchDecoration() => const InputDecoration(
  hintText: 'Enter district or city',
  prefixIcon: Icon(Icons.location_city_outlined),
  border: OutlineInputBorder(),
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
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  place.icon,
                  size: 28,
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
  const _SearchPrompt();
  @override
  Widget build(BuildContext context) => Center(
    child: _StateMessage(
      icon: Icons.travel_explore,
      title: 'Find accessible places',
      message: 'Enter a place name, category, district, or city above.',
    ),
  );
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.onClear});
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: _StateMessage(
        icon: Icons.search_off,
        title: 'No accessible places found',
        message: 'We could not find a public place matching "$query".',
        action: OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.refresh),
          label: const Text('Clear search'),
        ),
      ),
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
