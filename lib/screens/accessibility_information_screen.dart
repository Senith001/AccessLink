import 'package:flutter/material.dart';
import '../models/place_detail.dart';
import '../models/travel_mode.dart';
import '../services/directions_service.dart';
import '../widgets/place/rating_stars.dart';
import '../widgets/place/verified_badge.dart';
import '../widgets/place/accessibility_feature_tile.dart';
import '../widgets/place/place_action_buttons.dart';
import 'reviews_list_screen.dart';

class AccessibilityInformationScreen extends StatelessWidget {
  final PlaceDetail place;

  const AccessibilityInformationScreen({
    super.key,
    required this.place,
  });

  static Route<void> route({required PlaceDetail place}) {
    return MaterialPageRoute(
      builder: (_) => AccessibilityInformationScreen(place: place),
    );
  }

  static const Map<String, IconData> _iconMap = {
    'wheelchairAccessible': Icons.accessible,
    'accessibleToilet': Icons.wc,
    'elevator': Icons.elevator,
    'accessibleParking': Icons.local_parking,
    'tactilePaving': Icons.texture,
    'audioSupport': Icons.volume_up,
    'hearingSupport': Icons.hearing,
  };

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

  void _handleGetRoute(BuildContext context) async {
    if (place.latitude == null || place.longitude == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not available for directions')),
        );
      }
      return;
    }

    try {
      final directionsService = DirectionsService();
      await directionsService.openDirections(
        destinationLatitude: place.latitude!,
        destinationLongitude: place.longitude!,
        travelMode: TravelMode.driving,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open directions')),
        );
      }
    }
  }

  void _handleReadReviews(BuildContext context) {
    Navigator.push(
      context,
      ReviewsListScreen.route(
        placeId: place.id,
        placeName: place.name,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Place name
          Text(
            place.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),

          // Rating stars
          RatingStars(
            average: place.ratingAverage,
            count: place.ratingCount,
          ),
          const SizedBox(height: 12),

          // Verified badge and last updated
          Row(
            children: [
              VerifiedBadge(isVerified: place.isVerified),
              if (place.lastUpdated != null) ...[
                if (place.isVerified) const SizedBox(width: 12),
                Text(
                  _formatRelativeTime(place.lastUpdated),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility Information'),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with place info
            _buildHeader(context),
            
            const Divider(),
            
            // Accessibility features
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Render all 7 features in canonical order
                  ...PlaceDetail.featureOrder.map((featureKey) {
                    final feature = place.features[featureKey];
                    final label = PlaceDetail.featureLabels[featureKey] ?? featureKey;
                    final icon = _iconMap[featureKey] ?? Icons.help_outline;

                    if (feature == null) {
                      // Create a default unavailable feature
                      return AccessibilityFeatureTile(
                        icon: icon,
                        label: label,
                        feature: const AccessibilityFeature(
                          available: false,
                          notes: '',
                          verified: false,
                        ),
                      );
                    }

                    return AccessibilityFeatureTile(
                      icon: icon,
                      label: label,
                      feature: feature,
                    );
                  }),
                  
                  const SizedBox(height: 32),
                  
                  // Action buttons
                  PlaceActionButtons(
                    onGetRoute: () => _handleGetRoute(context),
                    onReadReviews: () => _handleReadReviews(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}