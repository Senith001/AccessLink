import 'package:flutter/material.dart';
import '../models/place_detail.dart';
import '../models/travel_mode.dart';
import '../repositories/place_repository.dart';
import '../services/directions_service.dart';
import '../widgets/place/photo_gallery.dart';
import '../widgets/place/rating_stars.dart';
import '../widgets/place/verified_badge.dart';
import '../widgets/place/opening_hours_tile.dart';
import '../widgets/place/contact_tile.dart';
import '../widgets/place/place_action_buttons.dart';
import 'accessibility_information_screen.dart';
import 'reviews_list_screen.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final String? placeId;
  final PlaceDetail? place;

  const PlaceDetailsScreen({
    super.key,
    this.placeId,
    this.place,
  }) : assert(placeId != null || place != null, 'Either placeId or place must be provided');

  static Route<void> route({String? placeId, PlaceDetail? place}) {
    return MaterialPageRoute(
      builder: (_) => PlaceDetailsScreen(placeId: placeId, place: place),
    );
  }

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  PlaceDetail? _place;
  bool _isLoading = false;
  String? _errorMessage;
  final PlaceRepository _placeRepository = PlaceRepository();
  final DirectionsService _directionsService = DirectionsService();

  @override
  void initState() {
    super.initState();
    if (widget.place != null) {
      _place = widget.place;
    } else {
      _loadPlaceDetail();
    }
  }

  Future<void> _loadPlaceDetail() async {
    if (widget.placeId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final place = await _placeRepository.getPlaceDetail(widget.placeId!);
      setState(() {
        _place = place;
        _isLoading = false;
        _errorMessage = place == null ? 'This place could not be found.' : null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  String _formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return 'Updated ${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return 'Updated ${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return 'Updated ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Updated recently';
    }
  }

  void _handleGetRoute() async {
    if (_place?.latitude == null || _place?.longitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not available for directions')),
        );
      }
      return;
    }

    try {
      await _directionsService.openDirections(
        destinationLatitude: _place!.latitude!,
        destinationLongitude: _place!.longitude!,
        travelMode: TravelMode.driving,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open directions')),
        );
      }
    }
  }

  void _handleReadReviews() {
    if (_place != null) {
      Navigator.push(
        context,
        ReviewsListScreen.route(
          placeId: _place!.id,
          placeName: _place!.name,
        ),
      );
    }
  }

  Widget _buildAccessibilityInfoTile() {
    if (_place == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        button: true,
        label: 'View accessibility information for this place',
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                AccessibilityInformationScreen.route(place: _place!),
              );
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.accessible,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accessibility Information',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (_place!.accessibilityScore > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'View wheelchair, toilet, elevator and more',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_place?.name ?? 'Place details'),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPlaceDetail,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _place == null
                  ? const Center(
                      child: Text('This place could not be found.'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo Gallery
                          if (_place!.photos.isNotEmpty)
                            PhotoGallery(photos: _place!.photos),
                          if (_place!.photos.isNotEmpty) const SizedBox(height: 24),

                          // Name and category
                          Text(
                            _place!.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (_place!.categoryName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _place!.categoryName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Rating stars
                          RatingStars(
                            average: _place!.ratingAverage,
                            count: _place!.ratingCount,
                          ),
                          const SizedBox(height: 12),

                          // Verified badge and last updated
                          Row(
                            children: [
                              VerifiedBadge(isVerified: _place!.isVerified),
                              if (_place!.lastUpdated != null) ...[
                                if (_place!.isVerified) const SizedBox(width: 12),
                                Text(
                                  _formatRelativeTime(_place!.lastUpdated),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Opening hours
                          OpeningHoursTile(openingHours: _place!.openingHours),
                          const SizedBox(height: 16),

                          // Contact information
                          ContactTile(contact: _place!.contact),
                          const SizedBox(height: 16),

                          // Accessibility Information entry
                          _buildAccessibilityInfoTile(),
                          const SizedBox(height: 24),

                          // Action buttons
                          PlaceActionButtons(
                            onGetRoute: _handleGetRoute,
                            onReadReviews: _handleReadReviews,
                          ),
                        ],
                      ),
                    ),
    );
  }
}