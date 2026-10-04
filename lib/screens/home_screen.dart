import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/database/firestore_collections.dart';
import '../models/accessibility_score.dart';
import '../models/search_place.dart';
import 'map_screen.dart';
import 'place_details_screen.dart';
import 'search_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialPlaces = const []});

  final List<Map<String, dynamic>> initialPlaces;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SearchPlace> _places = const [];
  bool _isLoadingPlaces = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    if (widget.initialPlaces.isNotEmpty) {
      setState(() {
        _places = widget.initialPlaces
            .map(SearchPlace.fromData)
            .whereType<SearchPlace>()
            .toList();
        _isLoadingPlaces = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.places)
          .get();
      if (!mounted) return;
      setState(() {
        _places = snapshot.docs
            .map(SearchPlace.fromFirestore)
            .whereType<SearchPlace>()
            .toList();
        _isLoadingPlaces = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPlaces = false);
    }
  }

  void _openSearch(BuildContext context) {
    _openSearchWithFilter(context, null);
  }

  void _openNearbyPlaces(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          initialPlaces: widget.initialPlaces,
          initialNearbyOnly: true,
          enableFavorites: true,
        ),
      ),
    );
  }

  void _openSearchWithFilter(BuildContext context, String? filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          initialPlaces: widget.initialPlaces,
          initialFilter: filter,
          enableFavorites: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Accessibility map'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  children: [
                    _SearchLauncher(onTap: () => _openSearch(context)),
                    const SizedBox(height: 16),
                    const _PromoBanner(),
                    const SizedBox(height: 16),
                    _LocationSelector(onTap: () => _openNearbyPlaces(context)),
                    const SizedBox(height: 18),
                    Text(
                      'Quick accessibility',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _AccessibilityShortcuts(
                      onFilterSelected: (filter) =>
                          _openSearchWithFilter(context, filter),
                    ),
                    const SizedBox(height: 18),
                    _MapPreview(
                      places: _places,
                      onOpenMap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MapScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_isLoadingPlaces)
                      const SizedBox(
                        height: 150,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_places.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('No nearby places available yet.'),
                        ),
                      )
                    else ...[
                      const _NearbySectionTitle(),
                      const SizedBox(height: 10),
                      _NearbyPlacesList(
                        places: _places,
                        onOpenDetails: (place) => Navigator.push(
                          context,
                          PlaceDetailsScreen.route(placeId: place.id),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Search accessible places',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search accessible places',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 140,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find Accessible Places Near You',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Discover public places with helpful accessibility details before you visit.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.82,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.accessible_forward,
                size: 42,
                color: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationSelector extends StatelessWidget {
  const _LocationSelector({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Find nearby public places',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.my_location_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Find nearby public places',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.near_me_outlined, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbySectionTitle extends StatelessWidget {
  const _NearbySectionTitle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Nearby places',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          defaultSearchLocation.label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.72)),
        ),
      ],
    );
  }
}

class _NearbyPlacesList extends StatelessWidget {
  const _NearbyPlacesList({required this.places, this.onOpenDetails});

  final List<SearchPlace> places;
  final void Function(SearchPlace place)? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final nearbyPlaces = searchPlacesSortedByDistance(places);

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: nearbyPlaces.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _NearbyPlaceCard(
          place: nearbyPlaces[index],
          onOpenDetails: onOpenDetails,
        ),
      ),
    );
  }
}

class _AccessibilityShortcuts extends StatelessWidget {
  const _AccessibilityShortcuts({required this.onFilterSelected});

  final ValueChanged<String> onFilterSelected;

  static const _items = <(IconData, String, String)>[
    (Icons.accessible_forward, 'Wheelchair', 'wheelchairaccessible'),
    (Icons.local_parking, 'Parking', 'accessibleparking'),
    (Icons.wc, 'Toilet', 'accessibletoilet'),
    (Icons.elevator, 'Elevator', 'elevator'),
    (Icons.volume_up, 'Audio', 'audiosupport'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 76,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final item in _items)
            Expanded(
              child: InkWell(
                onTap: () => onFilterSelected(item.$3),
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.45),
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.$1,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.places, required this.onOpenMap});

  final List<SearchPlace> places;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mappedPlaces = places.where((place) => place.hasCoordinates).toList();
    final center = mappedPlaces.isNotEmpty
        ? LatLng(mappedPlaces.first.latitude!, mappedPlaces.first.longitude!)
        : LatLng(
            defaultSearchLocation.latitude,
            defaultSearchLocation.longitude,
          );

    return Semantics(
      button: true,
      label: 'Open interactive map',
      child: InkWell(
        onTap: onOpenMap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AbsorbPointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: mappedPlaces.isEmpty ? 12 : 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.accesslink',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            defaultSearchLocation.latitude,
                            defaultSearchLocation.longitude,
                          ),
                          width: 34,
                          height: 34,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.onPrimary,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.my_location,
                              size: 16,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        ...mappedPlaces
                            .take(8)
                            .map(
                              (place) => Marker(
                                point: LatLng(
                                  place.latitude!,
                                  place.longitude!,
                                ),
                                width: 42,
                                height: 42,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _mapMarkerColor(
                                      context,
                                      place.category,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    place.icon,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mappedPlaces.isEmpty
                              ? 'Tap to open map'
                              : '${mappedPlaces.length} places - tap to open map',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(
                        Icons.open_in_full,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _mapMarkerColor(BuildContext context, String category) {
  if (MediaQuery.highContrastOf(context)) {
    return Theme.of(context).colorScheme.primary;
  }

  final normalized = category.trim().toLowerCase();
  if (normalized.contains('hospital') || normalized.contains('clinic')) {
    return Colors.red;
  }
  if (normalized.contains('restaurant') || normalized.contains('food')) {
    return Colors.orange;
  }
  if (normalized.contains('park')) return Colors.indigo;
  if (normalized.contains('bank')) return Colors.amber.shade800;
  if (normalized.contains('toilet') || normalized.contains('wash')) {
    return Colors.teal;
  }
  if (normalized.contains('pharmacy') || normalized.contains('medical')) {
    return Colors.green;
  }

  return Theme.of(context).colorScheme.primary;
}

class _NearbyPlaceCard extends StatelessWidget {
  const _NearbyPlaceCard({required this.place, this.onOpenDetails});

  final SearchPlace place;
  final void Function(SearchPlace place)? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 164,
      child: InkWell(
        onTap: onOpenDetails == null ? null : () => onOpenDetails!(place),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(place.icon, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 10),
              Text(
                place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${place.category} . ${place.distance}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              if (AccessibilityScore.fromPlace(place).canShow) ...[
                const SizedBox(height: 6),
                _HomeScoreBadge(place: place),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeScoreBadge extends StatelessWidget {
  const _HomeScoreBadge({required this.place});

  final SearchPlace place;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        AccessibilityScore.fromPlace(place).label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
