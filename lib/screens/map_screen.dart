import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../models/accessibility_rating.dart';
import '../services/place_service.dart';
import '../services/travel_time_service.dart';
import '../services/directions_service.dart';
import '../services/rating_service.dart';
import '../services/report_service.dart';
import '../services/admin_service.dart';
import 'admin_reports_screen.dart';
import 'place_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final PlaceService _placeService = PlaceService();
  final TravelTimeService _travelTimeService = TravelTimeService();
  final DirectionsService _directionsService = DirectionsService();
  final RatingService _ratingService = RatingService();
  final ReportService _reportService = ReportService();
  final AdminService _adminService = AdminService();
  final MapController _mapController = MapController();

  late Future<List<Place>> _placesFuture;
  String _selectedCategory = 'All';
  LatLng? _currentLocation;

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

  Color _categoryColor(String category) {
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
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.blue.shade700),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.blue.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaceDetails(Place place, Place startPlace) {
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
      builder: (sheetContext) {
        final color = _categoryColor(place.categoryName);

        return DraggableScrollableSheet(
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: _PlaceDetailsContent(
                  scrollController: controller,
                  place: place,
                  color: color,
                  distanceKm: distanceKm,
                  estimatedMinutes: estimatedMinutes,
                  currentLocation: _currentLocation,
                  directionsService: _directionsService,
                  ratingService: _ratingService,
                  reportService: _reportService,
                  adminService: _adminService,
                  buildTag: _buildTag,
                  categoryIcon: _categoryIcon,
                ),
              ),
            );
          },
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
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        toolbarHeight: 64,
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

          final mapCenter = _currentLocation ??
              LatLng(startPlace.latitude, startPlace.longitude);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: 12,
                ),
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
                              color: Colors.blue.shade700,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.white.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.filter_list_alt,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Live public places',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                if (hasError)
                                  const Icon(Icons.warning_amber_rounded,
                                      color: Colors.orange)
                                else if (isLoading)
                                  const SizedBox.shrink()
                                else
                                  const Icon(Icons.check_circle,
                                      color: Colors.green)
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
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOutCubic,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue.shade700
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Colors.blue.shade700
                                                      .withValues(alpha: 0.18),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.04),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
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
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _categoryIcon(category),
                                                  size: 16,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.black54,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  category,
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.black87,
                                                    fontWeight: FontWeight.w600,
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

              // Floating actions: recenter + loading indicator
              Positioned(
                bottom: 22,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                        onPressed: () {
                          final target = _currentLocation ?? mapCenter;
                          _mapController.move(target, 14.0);
                        },
                        child: const Icon(Icons.my_location, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
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
                            Text('Loading places',
                                style: TextStyle(fontSize: 12)),
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

// ---------------------------------------------------------------------------
// _PlaceDetailsContent – extracted StatefulWidget for the bottom-sheet body
// so that rating / report interactions can call setState independently
// without rebuilding the entire MapScreen.
// ---------------------------------------------------------------------------

class _PlaceDetailsContent extends StatefulWidget {
  final ScrollController scrollController;
  final Place place;
  final Color color;
  final double distanceKm;
  final int estimatedMinutes;
  final LatLng? currentLocation;
  final DirectionsService directionsService;
  final RatingService ratingService;
  final ReportService reportService;
  final AdminService adminService;
  final Widget Function(String text, {IconData? icon}) buildTag;
  final IconData Function(String category) categoryIcon;

  const _PlaceDetailsContent({
    required this.scrollController,
    required this.place,
    required this.color,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.currentLocation,
    required this.directionsService,
    required this.ratingService,
    required this.reportService,
    required this.adminService,
    required this.buildTag,
    required this.categoryIcon,
  });

  @override
  State<_PlaceDetailsContent> createState() => _PlaceDetailsContentState();
}

class _PlaceDetailsContentState extends State<_PlaceDetailsContent> {
  PlaceAccessibilityScore? _score;
  int? _userRating;
  bool _isRatingLoading = true;
  bool _isSubmittingRating = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRatingData();
    _checkAdmin();
  }

  Future<void> _loadRatingData() async {
    try {
      final results = await Future.wait([
        widget.ratingService.getPlaceScore(widget.place.id),
        widget.ratingService.getUserRating(widget.place.id),
      ]);

      if (!mounted) return;

      setState(() {
        _score = results[0] as PlaceAccessibilityScore;
        final userRating = results[1] as AccessibilityRating?;
        _userRating = userRating?.rating;
        _isRatingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRatingLoading = false;
      });
    }
  }

  Future<void> _checkAdmin() async {
    try {
      final isAdmin = await widget.adminService.isCurrentUserAdmin();
      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
      });
    } catch (_) {
      // Not admin.
    }
  }

  Future<void> _submitRating(int rating) async {
    if (rating < 1 || rating > 5) return;

    setState(() => _isSubmittingRating = true);

    try {
      await widget.ratingService.submitRating(
        placeId: widget.place.id,
        rating: rating,
      );

      // Reload to get fresh aggregate.
      final score =
          await widget.ratingService.getPlaceScore(widget.place.id);

      if (!mounted) return;
      setState(() {
        _userRating = rating;
        _score = score;
        _isSubmittingRating = false;
      });

      _showSnackBar('Rating submitted!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingRating = false);
      _showSnackBar('Failed to submit rating: $e');
    }
  }

  void _showReportDialog() {
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.flag, color: Colors.orange.shade700),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Report Incorrect Info',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reporting: ${widget.place.name}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Reason *',
                      hintText: 'Describe what is incorrect...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            _showSnackBar(
                                'Please enter a reason for the report.');
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            await widget.reportService.submitReport(
                              placeId: widget.place.id,
                              placeName: widget.place.name,
                              reason: reason,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(dialogContext);
                            _showSnackBar(
                                'Report submitted successfully. Thank you!');
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (!ctx.mounted) return;
                            _showSnackBar('Failed to submit report: $e');
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: Text(isSubmitting ? 'Submitting...' : 'Submit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final color = widget.color;

    return SingleChildScrollView(
      controller: widget.scrollController,
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
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: color.withValues(alpha: 0.25), width: 2),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: color,
                  child: Text(
                    (place.name.isNotEmpty ? place.name[0] : '?')
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                        widget.buildTag(place.categoryName,
                            icon: widget.categoryIcon(place.categoryName)),
                        widget.buildTag(
                            '${widget.distanceKm.toStringAsFixed(2)} km',
                            icon: Icons.near_me_outlined),
                        widget.buildTag('${widget.estimatedMinutes} min',
                            icon: Icons.schedule),
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
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on,
                    size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    place.address.isNotEmpty
                        ? place.address
                        : 'Address not available',
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Accessibility Score + Rating Section ──
          _buildAccessibilitySection(),

          const SizedBox(height: 16),

          // Full Details Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaceDetailsScreen(
                      place: place,
                      currentLocation: widget.currentLocation,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline, size: 20),
              label: const Text(
                'View Full Details & Reviews',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Buttons row: Directions + Report
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await widget.directionsService.openDirections(
                        destinationLatitude: place.latitude,
                        destinationLongitude: place.longitude,
                        originLatitude:
                            widget.currentLocation?.latitude,
                        originLongitude:
                            widget.currentLocation?.longitude,
                      );
                    },
                    icon: const Icon(Icons.directions, size: 22),
                    label: const Text(
                      'Directions',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor:
                          Colors.blue.shade700.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final user =
                        FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      _showSnackBar(
                          'Please sign in to report.');
                      return;
                    }
                    _showReportDialog();
                  },
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  label: const Text(
                    'Report',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor:
                        Colors.orange.shade700.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Admin button (only visible for admin users)
          if (_isAdmin) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminReportsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings, size: 20),
                label: const Text(
                  'Admin – Review Reports',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccessibilitySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(Icons.accessible, size: 20, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Text(
                'Accessibility Rating',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isRatingLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            // Aggregate score display
            if (_score != null && _score!.ratingCount > 0)
              Row(
                children: [
                  ...List.generate(5, (i) {
                    final starIndex = i + 1;
                    final avg = _score!.averageScore;
                    IconData icon;
                    if (avg >= starIndex) {
                      icon = Icons.star;
                    } else if (avg >= starIndex - 0.5) {
                      icon = Icons.star_half;
                    } else {
                      icon = Icons.star_border;
                    }
                    return Icon(icon, color: Colors.amber.shade700, size: 22);
                  }),
                  const SizedBox(width: 8),
                  Text(
                    _score!.averageScore.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${_score!.ratingCount} ${_score!.ratingCount == 1 ? 'rating' : 'ratings'})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              )
            else
              Text(
                'No ratings yet. Be the first!',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.amber.shade800,
                  fontStyle: FontStyle.italic,
                ),
              ),

            const SizedBox(height: 12),

            // User's interactive rating
            if (FirebaseAuth.instance.currentUser != null) ...[
              Text(
                _userRating != null
                    ? 'Your rating: $_userRating / 5 (tap to change)'
                    : 'Tap a star to rate:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  ...List.generate(5, (i) {
                    final starValue = i + 1;
                    final isFilled =
                        _userRating != null && starValue <= _userRating!;
                    return GestureDetector(
                      onTap: _isSubmittingRating
                          ? null
                          : () => _submitRating(starValue),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          isFilled ? Icons.star : Icons.star_border,
                          color: isFilled
                              ? Colors.amber.shade700
                              : Colors.amber.shade400,
                          size: 32,
                        ),
                      ),
                    );
                  }),
                  if (_isSubmittingRating) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ] else
              Text(
                'Sign in to rate this place.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.amber.shade800,
                ),
              ),
          ],
        ],
      ),
    );
  }
}