import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/place_detail.dart';
import '../models/review.dart';
import '../models/travel_mode.dart';
import '../models/verification_record.dart';
import '../repositories/place_repository.dart';
import '../repositories/review_repository.dart';
import '../services/directions_service.dart';
import '../services/rating_review_service.dart';
import '../services/verification_service.dart';
import '../services/photo_upload_service.dart';
import '../services/cloudinary_client.dart';
import '../widgets/place/photo_gallery.dart';
import '../widgets/place/rating_stars.dart';
import '../widgets/place/verified_badge.dart';
import '../widgets/place/opening_hours_tile.dart';
import '../widgets/place/contact_tile.dart';
import '../widgets/place/place_action_buttons.dart';
import '../widgets/place/rate_place_dialog.dart';
import '../widgets/place/write_review_dialog.dart';
import '../widgets/place/upload_photo_dialog.dart';
import '../widgets/place/report_place_dialog.dart';
import 'accessibility_information_screen.dart';
import 'reviews_list_screen.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final String? placeId;
  final PlaceDetail? place;

  const PlaceDetailsScreen({super.key, this.placeId, this.place})
    : assert(
        placeId != null || place != null,
        'Either placeId or place must be provided',
      );

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
  bool _isUploadingPhoto = false;
  final PlaceRepository _placeRepository = PlaceRepository();
  final ReviewRepository _reviewRepository = ReviewRepository();
  final DirectionsService _directionsService = DirectionsService();
  final VerificationService _verificationService = VerificationService();
  final PhotoUploadService _photoUploadService = PhotoUploadService();

  List<Review> _recentReviews = [];
  Review? _userReview;
  VerificationRecord? _verificationRecord;
  final Set<String> _expandedReviews = {};

  @override
  void initState() {
    super.initState();
    if (widget.place != null) {
      _place = widget.place;
      _loadAdditionalData(widget.place!.id);
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
      if (!mounted) return;

      setState(() {
        _place = place;
        _isLoading = false;
        _errorMessage = place == null ? 'This place could not be found.' : null;
      });

      if (place != null) {
        _loadAdditionalData(place.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _loadAdditionalData(String placeId) async {
    try {
      final reviews = await _reviewRepository.getReviewsForPlace(
        placeId,
        limit: 5,
      );
      final userRev = await _reviewRepository.getUserReviewForPlace(placeId);
      final verRecords = await _verificationService.getVerificationRecords(
        placeId,
      );

      if (!mounted) return;
      setState(() {
        _recentReviews = reviews;
        _userReview = userRev;
        _verificationRecord = verRecords.isEmpty ? null : verRecords.first;
      });
    } catch (_) {}
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
          const SnackBar(
            content: Text('Location not available for directions'),
          ),
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
        ReviewsListScreen.route(placeId: _place!.id, placeName: _place!.name),
      ).then((_) {
        // Refresh reviews after returning
        _loadAdditionalData(_place!.id);
      });
    }
  }

<<<<<<< HEAD
  Future<void> _handleRatePlace() async {
    if (_place == null) return;

    final result = await RatePlaceDialog.show(
      context,
      placeId: _place!.id,
      placeName: _place!.name,
      existingReview: _userReview,
    );

    if (result != null && mounted) {
      setState(() {
        _place = _place!.copyWith(
          ratingAverage: result.average,
          ratingCount: result.count,
        );
      });
      _loadAdditionalData(_place!.id);
    }
  }

  Future<void> _handleWriteReview() async {
    if (_place == null) return;

    final newReview = await WriteReviewDialog.show(
      context,
      placeId: _place!.id,
      placeName: _place!.name,
      existingReview: _userReview,
    );

    if (newReview != null && mounted) {
      _loadPlaceDetail();
    }
  }

  Future<void> _handleUploadPhoto() async {
    if (_place == null) return;

    final photo = await UploadPhotoDialog.show(
      context,
      placeId: _place!.id,
      placeName: _place!.name,
    );

    if (photo != null && mounted) {
      final updatedPhotos = List<String>.from(_place!.photos)
        ..insert(0, photo.url);
      setState(() {
        _place = _place!.copyWith(photos: updatedPhotos);
      });
    }
  }

  Future<void> _handleReportIncorrectInfo() async {
    if (_place == null) return;

    await ReportPlaceDialog.show(
      context,
      placeId: _place!.id,
      placeName: _place!.name,
    );
  }

  Widget _buildVerificationCard() {
    if (_place == null) return const SizedBox.shrink();

    int verifiedCount = 0;
    for (final feat in _place!.features.values) {
      if (feat.verified) verifiedCount++;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (_verificationRecord != null)
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (_verificationRecord != null)
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          width: (_verificationRecord != null) ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VerifiedBadge(
                isVerified: (_verificationRecord != null),
                showFullLabel: true,
                verifiedDate:
                    _verificationRecord?.createdAt ?? _place!.lastUpdated,
                authorityDescription:
                    _verificationRecord?.publicAuthorityDescription,
              ),
              const Spacer(),
              if (_place!.lastUpdated != null)
                Text(
                  _formatRelativeTime(_place!.lastUpdated),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (_verificationRecord != null)
                ? '$verifiedCount of ${PlaceDetail.featureOrder.length} accessibility features audited and verified.'
                : 'Accessibility information is submitted by the community and has not yet undergone official staff audit.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingAndScoreSection() {
    if (_place == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Accessibility Rating',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Accessibility Score Badge (Preserved separate from community rating)
              if (_place!.accessibilityScore > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_place!.accessibilityScore}% Score',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Community Average and Stars
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RatingStars(
                average: _place!.ratingAverage,
                count: _place!.ratingCount,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _handleRatePlace,
                icon: Icon(
                  _userReview != null ? Icons.star : Icons.star_border,
                  size: 18,
                ),
                label: Text(
                  _userReview != null
                      ? 'Your Rating: ${_userReview!.rating}★'
                      : 'Rate Place',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  minimumSize: const Size(48, 44),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleAddPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to submit a photo')),
        );
      }
      return;
    }

    if (_place == null) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final submissionId = await _photoUploadService.pickAndSubmitPhoto(
        placeId: _place!.id,
        placeName: _place!.name,
      );

      if (mounted && submissionId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo submitted for review! Thank you for contributing.')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AddPhoto] $e');
      }
      
      if (mounted) {
        String errorMessage = 'Failed to submit photo';
        
        // Show more informative messages for known error types
        if (e is CloudinaryException || e is StateError || e is ArgumentError) {
          String detailedMessage = e.toString();
          
          // Clean up common error type prefixes for user display
          detailedMessage = detailedMessage
              .replaceFirst('StateError: ', '')
              .replaceFirst('Invalid argument(s): ', '')
              .replaceFirst('CloudinaryException: ', '');
          
          // Trim very long messages
          if (detailedMessage.length > 200) {
            detailedMessage = '${detailedMessage.substring(0, 200)}...';
          }
          
          errorMessage = detailedMessage;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  Widget _buildAccessibilityInfoTile() {
    if (_place == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        button: true,
        label: 'View detailed accessibility information for this place',
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
                    Icons.accessible_forward,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detailed Accessibility Information',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Wheelchair, restrooms, elevators, tactile paving, audio & hearing support',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Accessibility Reviews (${_place?.ratingCount ?? 0})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _handleWriteReview,
                icon: const Icon(Icons.rate_review, size: 18),
                label: Text(
                  _userReview?.text.isNotEmpty == true
                      ? 'Edit Review'
                      : 'Write Review',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_recentReviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 36,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No detailed reviews written yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _handleWriteReview,
                    child: const Text('Be the first to write a review'),
                  ),
                ],
              ),
            )
          else ...[
            ..._recentReviews.take(3).map((review) {
              final isExpanded = _expandedReviews.contains(review.id);
              final isLong = review.text.length > 160;
              final displayText = (isLong && !isExpanded)
                  ? '${review.text.substring(0, 160)}...'
                  : review.text;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              review.userName.isNotEmpty
                                  ? review.userName
                                  : 'Anonymous Contributor',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(
                                i < review.rating
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 16,
                                color: Colors.amber.shade700,
                              );
                            }),
                          ),
                        ],
                      ),
                      if (review.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatRelativeTime(review.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (review.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          displayText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.3,
                          ),
                        ),
                        if (isLong)
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedReviews.remove(review.id);
                                } else {
                                  _expandedReviews.add(review.id);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                isExpanded ? 'Read less' : 'Read more',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            if (_recentReviews.length > 3 ||
                (_place != null && _place!.ratingCount > 3))
              Center(
                child: TextButton(
                  onPressed: _handleReadReviews,
                  child: const Text('View All Community Reviews →'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_place?.name ?? 'Place Details'),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo),
            tooltip: 'Upload accessibility photo',
            onPressed: _place == null ? null : _handleUploadPhoto,
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report incorrect information',
            onPressed: _place == null ? null : _handleReportIncorrectInfo,
          ),
        ],
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
          ? const Center(child: Text('This place could not be found.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Photo Gallery with Add Photo Trigger
                  PhotoGallery(
                    photos: _place!.photos,
                    onAddPhoto: _handleUploadPhoto,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _handleUploadPhoto,
                        icon: const Icon(Icons.camera_alt, size: 16),
                        label: const Text('Add Accessibility Photo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Name, Description, Address
                  Text(
                    _place!.name,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
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
                  if (_place!.address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${_place!.address}, ${_place!.district}, ${_place!.city}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // 3. Verification Card (Distinguishable badges & authority)
                  _buildVerificationCard(),
                  const SizedBox(height: 8),

                  // 4. Community Rating & Accessibility Score Card
                  _buildRatingAndScoreSection(),
                  const SizedBox(height: 8),

                  // 5. Detailed Accessibility Information Entry
                  _buildAccessibilityInfoTile(),
                  const SizedBox(height: 12),

                  // 6. Opening hours
                  OpeningHoursTile(openingHours: _place!.openingHours),
                  const SizedBox(height: 16),

                  // 7. Contact information
                  ContactTile(contact: _place!.contact),
                  const SizedBox(height: 16),

                  // 8. Reviews section (Recent reviews, Write Review, Read More)
                  _buildReviewsSection(),
                  const SizedBox(height: 16),

                  // 9. Primary Action Buttons
                  PlaceActionButtons(
                    onGetRoute: _handleGetRoute,
                    onReadReviews: _handleReadReviews,
                  ),
                  const SizedBox(height: 16),

                  // 10. Discoverable Report Incorrect Information Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OutlinedButton.icon(
                      onPressed: _handleReportIncorrectInfo,
                      icon: const Icon(
                        Icons.report_problem_outlined,
                        color: Colors.orange,
                      ),
                      label: const Text('Report Incorrect Information'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.orange.shade700),
                        foregroundColor: Colors.orange.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
