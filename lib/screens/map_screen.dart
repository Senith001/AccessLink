import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../accessibility/voice_guidance.dart';
import '../models/travel_mode.dart';
import '../services/place_service.dart';
import '../services/travel_time_service.dart';
import '../services/directions_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final PlaceService _placeService = PlaceService();
  final TravelTimeService _travelTimeService = TravelTimeService();
  final DirectionsService _directionsService = DirectionsService();
  final MapController _mapController = MapController();

  late Future<List<Place>> _placesFuture;
  String _selectedCategory = 'All';
  LatLng? _currentLocation;
  TravelMode _selectedTravelMode = TravelMode.driving;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final userLocation = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _currentLocation = userLocation;
      });

      _mapController.move(userLocation, 13.0);
    } catch (_) {
      // Fail safely; keep default map center instead.
    }
  }

  void _loadPlaces() {
    _placesFuture = _selectedCategory == 'All'
        ? _placeService.getPlaces()
        : _placeService.getPlacesByCategory(_selectedCategory);
  }

  void _onCategorySelected(String category) {
    VoiceGuidanceScope.announce(context, '$category places selected');
    if (category == _selectedCategory) return;

    setState(() {
      _selectedCategory = category;
      _loadPlaces();
    });
  }

  String _normalizeCategory(String value) => value.trim();

  static const List<String> _filterOptions = [
    'All',
    'Restaurants',
    'Hospitals',
    'Hotels',
    'Washrooms',
    'Fuel',
    'Pharmacies',
    'Banks',
    'Supermarkets',
    'Bus Stops',
    'Schools',
    'Parking',
  ];

  bool get _highContrast => MediaQuery.highContrastOf(context);
  Color get _primary => Theme.of(context).colorScheme.primary;

  Color _categoryColor(String category) {
    if (_highContrast) return _primary;
    final normalized = _normalizeCategory(category).toLowerCase();

    if (normalized.contains('wash') || normalized.contains('toilet')) {
      return Colors.teal;
    }
    if (normalized.contains('hotel')) return Colors.deepPurple;
    if (normalized.contains('restaurant') || normalized.contains('food')) {
      return Colors.orange;
    }
    if (normalized.contains('hospital') || normalized.contains('clinic')) {
      return Colors.red;
    }
    if (normalized.contains('pharmacy') || normalized.contains('medical')) {
      return Colors.green;
    }
    if (normalized.contains('school') || normalized.contains('education')) {
      return Colors.blue;
    }
    if (normalized.contains('bank')) return Colors.amber.shade800;
    if (normalized.contains('fuel')) return Colors.deepOrange;
    if (normalized.contains('park')) return Colors.indigo;
    if (normalized.contains('super')) return Colors.pink;
    if (normalized.contains('bus')) return Colors.cyan;

    return Colors.indigo;
  }

  IconData _categoryIcon(String category) {
    final normalized = _normalizeCategory(category).toLowerCase();

    if (normalized.contains('wash') || normalized.contains('toilet')) {
      return Icons.wc;
    }
    if (normalized.contains('hotel')) return Icons.hotel;
    if (normalized.contains('restaurant') || normalized.contains('food')) {
      return Icons.restaurant;
    }
    if (normalized.contains('hospital') || normalized.contains('clinic')) {
      return Icons.local_hospital;
    }
    if (normalized.contains('pharmacy') || normalized.contains('medical')) {
      return Icons.medical_services;
    }
    if (normalized.contains('school') || normalized.contains('education')) {
      return Icons.school;
    }
    if (normalized.contains('bank')) return Icons.account_balance;
    if (normalized.contains('fuel')) return Icons.local_gas_station;
    if (normalized.contains('park')) return Icons.local_parking;
    if (normalized.contains('super')) return Icons.shopping_basket;
    if (normalized.contains('bus')) return Icons.directions_bus;

    return Icons.place;
  }

  Widget _buildTag(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _primary),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaceDetails(Place place, Place startPlace) {
    VoiceGuidanceScope.announce(
      context,
      '${place.name}. ${place.categoryName}. ${place.address}. Choose a travel mode, then Directions.',
    );
    // Prefer the user's actual current location when calculating distance.
    final double startLat = _currentLocation?.latitude ?? startPlace.latitude;
    final double startLon = _currentLocation?.longitude ?? startPlace.longitude;

    final distanceKm = _travelTimeService.calculateDistanceKm(
      startLatitude: startLat,
      startLongitude: startLon,
      destinationLatitude: place.latitude,
      destinationLongitude: place.longitude,
    );

    final estimatedMinutes = _travelTimeService.calculateEstimatedTravelTime(
      distanceKm: distanceKm,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final color = _categoryColor(place.categoryName);

        return StatefulBuilder(
          builder: (context, setSheetState) => DraggableScrollableSheet(
            expand: false,
            builder: (_, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        // Header: avatar + name + tags
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (MediaQuery.textScalerOf(context).scale(16) <=
                                21)
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.25),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: color,
                                  child: Text(
                                    (place.name.isNotEmpty
                                            ? place.name[0]
                                            : '?')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildTag(
                                        place.categoryName,
                                        icon: _categoryIcon(place.categoryName),
                                      ),
                                      _buildTag(
                                        '${distanceKm.toStringAsFixed(2)} km',
                                        icon: Icons.near_me_outlined,
                                      ),
                                      if (_selectedTravelMode ==
                                          TravelMode.driving)
                                        _buildTag(
                                          '~$estimatedMinutes min driving',
                                          icon: Icons.schedule,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Address card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 20,
                                color: _primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  place.address.isNotEmpty
                                      ? place.address
                                      : 'Address not available',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    color: Colors.black,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Travel mode',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: TravelMode.values.map((mode) {
                            return ChoiceChip(
                              label: Text(mode.label),
                              avatar: Icon(
                                mode == TravelMode.driving
                                    ? Icons.directions_car
                                    : Icons.directions_transit,
                                size: 18,
                              ),
                              selected: _selectedTravelMode == mode,
                              onSelected: (selected) {
                                if (!selected) return;
                                setSheetState(() => _selectedTravelMode = mode);
                                VoiceGuidanceScope.announce(
                                  context,
                                  '${mode.label} selected',
                                );
                              },
                            );
                          }).toList(),
                        ),
                        if (_selectedTravelMode == TravelMode.transit) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Public transport routes and times are shown in Google Maps where available.',
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Buttons: same size
                        Row(
                          children: [
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 52,
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    VoiceGuidanceScope.announce(
                                      context,
                                      'Opening ${_selectedTravelMode.label} directions to ${place.name} in Google Maps',
                                    );
                                    try {
                                      await _directionsService.openDirections(
                                        travelMode: _selectedTravelMode,
                                        destinationLatitude: place.latitude,
                                        destinationLongitude: place.longitude,
                                        originLatitude:
                                            _currentLocation?.latitude,
                                        originLongitude:
                                            _currentLocation?.longitude,
                                      );
                                    } catch (_) {
                                      if (!context.mounted) return;
                                      VoiceGuidanceScope.announce(
                                        context,
                                        'Could not open directions. Please try again.',
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not open directions. Please try again.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.directions, size: 22),
                                  label: const Text(
                                    'Directions',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    foregroundColor: Colors.white,
                                    elevation: 3,
                                    shadowColor: _primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Public Places'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
      ),
      body: FutureBuilder<List<Place>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError;

          // Use data if available, otherwise fall back to local fallback places
          final places = snapshot.data ?? _placeService.getFallbackPlaces();

          final startPlace = places.isNotEmpty
              ? places.first
              : Place(
                  id: 'default',
                  name: 'Colombo',
                  address: 'Colombo, Sri Lanka',
                  categoryName: 'City',
                  location: GeoPoint(6.9271, 79.8612),
                  isVerified: false,
                );

          final mapCenter =
              _currentLocation ??
              LatLng(startPlace.latitude, startPlace.longitude);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: mapCenter, initialZoom: 12),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.accesslink',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_currentLocation != null)
                        Marker(
                          point: _currentLocation!,
                          width: 34,
                          height: 34,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ...places.map((place) {
                        final color = _categoryColor(place.categoryName);

                        return Marker(
                          point: LatLng(place.latitude, place.longitude),
                          width: 42,
                          height: 42,
                          child: GestureDetector(
                            onTap: () {
                              _showPlaceDetails(place, startPlace);
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _categoryIcon(place.categoryName),
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),

              // Top overlay: filter chips and label
              Positioned(
                top: 16,
                left: 12,
                right: 12,
                child: SafeArea(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                    ),
                    child: SingleChildScrollView(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: _highContrast ? 1 : 0.95,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerLow,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.filter_list_alt,
                                        size: 18,
                                        color: _primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Live public places',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (hasError)
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.orange,
                                      )
                                    else if (isLoading)
                                      const SizedBox.shrink()
                                    else
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _filterOptions.map((category) {
                                      final isSelected =
                                          _selectedCategory == category;

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? _primary
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: _primary
                                                          .withValues(
                                                            alpha: 0.18,
                                                          ),
                                                      blurRadius: 10,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ]
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.04,
                                                          ),
                                                      blurRadius: 4,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () =>
                                                  _onCategorySelected(category),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      _categoryIcon(category),
                                                      size: 16,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : (_highContrast
                                                                ? Colors.black
                                                                : Colors
                                                                      .black54),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      category,
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Colors.white
                                                            : Colors.black,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Floating actions: recenter + loading indicator
              Positioned(
                bottom: 22,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        heroTag: 'recenter',
                        mini: true,
                        backgroundColor: Colors.white,
                        tooltip: 'Center map',
                        onPressed: () {
                          VoiceGuidanceScope.announce(
                            context,
                            _currentLocation == null
                                ? 'Current location unavailable. Centering on the default area.'
                                : 'Centering map on your location',
                          );
                          final target = _currentLocation ?? mapCenter;
                          _mapController.move(target, 14.0);
                        },
                        child: Icon(Icons.my_location, color: _primary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Loading places',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}