import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../screens/place_details_screen.dart';
import '../services/place_service.dart';
import '../services/travel_time_service.dart';

/// Home discovery screen with case-insensitive search, category filtering,
/// location-based distance calculations, and navigation to PlaceDetailsScreen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PlaceService _placeService = PlaceService();
  final TravelTimeService _travelTimeService = TravelTimeService();
  final TextEditingController _searchController = TextEditingController();

  List<Place> _allPlaces = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  LatLng? _userLocation;
  String? _locationStatusMessage;

  static const List<String> _categories = [
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

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _resolveLocation();
    await _loadPlaces();
  }

  Future<void> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationStatusMessage =
              'Location services disabled. Showing Colombo area places.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _locationStatusMessage =
                'Location access denied. Distances shown from city center.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationStatusMessage =
              'Location permission permanently denied. Enable in Settings for nearby places.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 6));

      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _locationStatusMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationStatusMessage =
            'Could not retrieve current location. Using Colombo center.';
      });
    }
  }

  Future<void> _loadPlaces() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final places = await _placeService.getPlaces(
        latitude: _userLocation?.latitude,
        longitude: _userLocation?.longitude,
      );

      if (!mounted) return;
      setState(() {
        _allPlaces = places;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allPlaces = _placeService.getFallbackPlaces();
        _isLoading = false;
      });
    }
  }

  bool _matchesCategory(Place place, String category) {
    if (category == 'All') return true;
    final catLower = category.toLowerCase();
    final placeCatLower = place.categoryName.toLowerCase();

    if (catLower.contains('wash') || catLower.contains('toilet')) {
      return placeCatLower.contains('wash') || placeCatLower.contains('toilet');
    }
    if (catLower.contains('rest')) return placeCatLower.contains('rest');
    if (catLower.contains('hosp')) return placeCatLower.contains('hosp');
    if (catLower.contains('hotel')) return placeCatLower.contains('hotel');
    if (catLower.contains('pharm')) return placeCatLower.contains('pharm');
    if (catLower.contains('bank')) return placeCatLower.contains('bank');
    if (catLower.contains('super')) return placeCatLower.contains('super');
    if (catLower.contains('bus')) return placeCatLower.contains('bus');
    if (catLower.contains('school')) return placeCatLower.contains('school');
    if (catLower.contains('fuel')) return placeCatLower.contains('fuel');
    if (catLower.contains('park')) return placeCatLower.contains('park');

    return placeCatLower.contains(catLower);
  }

  List<Place> get _filteredPlaces {
    final query = _searchQuery.trim().toLowerCase();

    return _allPlaces.where((place) {
      final matchesCat = _matchesCategory(place, _selectedCategory);
      final matchesQuery = query.isEmpty ||
          place.name.toLowerCase().contains(query) ||
          place.address.toLowerCase().contains(query) ||
          place.categoryName.toLowerCase().contains(query);
      return matchesCat && matchesQuery;
    }).toList();
  }

  Color _categoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('wash') || lower.contains('toilet')) return Colors.teal;
    if (lower.contains('hotel')) return Colors.deepPurple;
    if (lower.contains('rest') || lower.contains('food')) return Colors.orange;
    if (lower.contains('hosp') || lower.contains('clinic')) return Colors.red;
    if (lower.contains('pharm') || lower.contains('med')) return Colors.green;
    if (lower.contains('school') || lower.contains('edu')) return Colors.blue;
    if (lower.contains('bank')) return Colors.amber.shade800;
    if (lower.contains('fuel')) return Colors.deepOrange;
    if (lower.contains('park')) return Colors.indigo;
    if (lower.contains('super')) return Colors.pink;
    if (lower.contains('bus')) return Colors.cyan;
    return const Color(0xFF1976D2);
  }

  IconData _categoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('wash') || lower.contains('toilet')) return Icons.wc;
    if (lower.contains('hotel')) return Icons.hotel;
    if (lower.contains('rest') || lower.contains('food')) {
      return Icons.restaurant;
    }
    if (lower.contains('hosp') || lower.contains('clinic')) {
      return Icons.local_hospital;
    }
    if (lower.contains('pharm') || lower.contains('med')) {
      return Icons.medical_services;
    }
    if (lower.contains('school') || lower.contains('edu')) return Icons.school;
    if (lower.contains('bank')) return Icons.account_balance;
    if (lower.contains('fuel')) return Icons.local_gas_station;
    if (lower.contains('park')) return Icons.local_parking;
    if (lower.contains('super')) return Icons.shopping_cart;
    if (lower.contains('bus')) return Icons.directions_bus;
    return Icons.place;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPlaces;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.accessible_forward, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'AccessLink',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // ── Search & Filter Header Container ──
          Container(
            color: const Color(0xFF1976D2),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search places (e.g. Hospital, Hotel)...',
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF1976D2)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Location Banner (if location unavailable or permission denied)
          if (_locationStatusMessage != null)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationStatusMessage!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),

          // ── Category Filter Horizontal Scroll ──
          Container(
            height: 48,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    }
                  },
                  selectedColor: const Color(0xFF1976D2),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),

          // ── Places Discovery List ──
          Expanded(
            child: _buildPlacesList(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesList(List<Place> places) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (places.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No places matching "$_searchQuery"'
                    : 'No places found in $_selectedCategory',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try clearing your search query or selecting "All".',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _resolveLocation();
        await _loadPlaces();
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: places.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final place = places[index];
          final catColor = _categoryColor(place.categoryName);

          double? distanceKm;
          int? travelMinutes;
          if (_userLocation != null) {
            distanceKm = _travelTimeService.calculateDistanceKm(
              startLatitude: _userLocation!.latitude,
              startLongitude: _userLocation!.longitude,
              destinationLatitude: place.latitude,
              destinationLongitude: place.longitude,
            );
            travelMinutes = _travelTimeService.calculateEstimatedTravelTime(
              distanceKm: distanceKm,
            );
          }

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaceDetailsScreen(
                      place: place,
                      currentLocation: _userLocation,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Category icon, Place Name, Verified badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              catColor.withValues(alpha: 0.15),
                          foregroundColor: catColor,
                          child: Icon(_categoryIcon(place.categoryName),
                              size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    place.categoryName,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: catColor,
                                    ),
                                  ),
                                  if (distanceKm != null) ...[
                                    Text(
                                      ' • ${distanceKm.toStringAsFixed(1)} km',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (travelMinutes != null)
                                      Text(
                                        ' (~$travelMinutes min)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (place.isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified,
                                    size: 13, color: Colors.green.shade800),
                                const SizedBox(width: 3),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Address
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.address.isNotEmpty
                                ? place.address
                                : 'Address not specified',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Accessibility summary tags
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (place.wheelchair == AccessibilityStatus.yes)
                          _featureBadge(
                              'Wheelchair Access', Icons.accessible, Colors.green)
                        else if (place.wheelchair == AccessibilityStatus.no)
                          _featureBadge('No Wheelchair Access',
                              Icons.accessible, Colors.red)
                        else
                          _featureBadge('Wheelchair Unknown', Icons.accessible,
                              Colors.grey),
                        if (place.ramp == AccessibilityStatus.yes)
                          _featureBadge(
                              'Ramp', Icons.accessible_forward, Colors.green),
                        if (place.elevator == AccessibilityStatus.yes)
                          _featureBadge('Elevator', Icons.elevator, Colors.green),
                        if (place.accessibleToilet == AccessibilityStatus.yes)
                          _featureBadge('Restroom', Icons.wc, Colors.green),
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
  }

  Widget _featureBadge(String label, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.shade800),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color.shade800,
            ),
          ),
        ],
      ),
    );
  }
}